import 'dart:async';
import 'dart:convert';
import 'package:math_expressions/math_expressions.dart';
import '../../../obd2.dart';

/// AT = Attention Command (ELM327 modem prefix)
/// ECU = Engine Control Unit
/// PID = Parameter Identifier
/// ASCII = American Standard Code for Information Interchange
/// SAE = Society of Automotive Engineers
/// J1979 = OBD-II emissions diagnostic standard

/// Core low-level OBD-II engine for SAE J1979 communication.
///
/// This abstract class manages:
/// - Command lifecycle
/// - ELM327 initialization
/// - ASCII request/response parsing
/// - PID query execution
/// - Mathematical evaluation of PID formulas
///
/// Concrete transport implementations (e.g., Bluetooth, WiFi)
/// must extend this class and implement physical I/O behavior.
abstract class AdapterOBD2 {

  /// SAE J1979 protocol handler.
  ///
  /// Since this package is SAE J1979-exclusive,
  /// the protocol is permanently bound here.
  late final SaeJ1979 protocol;

  /// Indicates whether the transport layer is currently connected.
  ///
  /// Must be implemented by subclasses.
  bool get isConnected;

  /// Stream of raw incoming bytes from the physical transport layer.
  ///
  /// Must be implemented by subclasses.
  Stream<List<int>> get incomingData;

  /// Writes raw bytes to the physical transport layer.
  ///
  /// Must be implemented by subclasses.
  ///
  /// ### Parameters:
  /// - (`List<int>`): data - ASCII-encoded command bytes.
  Future<void> write(List<int> data);

  /// Disconnects the physical transport layer.
  ///
  /// Must be implemented by subclasses.
  Future<void> disconnect();

  /// Indicates whether the adapter is currently initializing.
  bool _isInitializingAdapter = false;

  /// The last ASCII command sent to the adapter.
  ///
  /// Useful for debugging timeouts or failures.
  /// String _lastCommand = '';

  /// Internal classification of the last request.
  ///
  /// 100 → Initialization (AT commands)
  /// 400 → PID query (Mode 01/09)
  /// int _requestCode = 0;

  /// Internal ASCII response buffer.
  ///
  /// Accumulates fragmented ELM327 responses.
  String _responseBuffer = '';

  /// Completer used to signal completion of a pending request.
  Completer<String>? _pendingResponseCompleter;

  /// Creates a new SAE J1979 OBD-II adapter.
  ///
  /// Automatically subscribes to the [incomingData] stream.
  AdapterOBD2() {
    protocol = SaeJ1979(this);
    incomingData.listen(_handleIncomingData);
  }

  /// Initializes the ELM327 adapter for SAE J1979 communication.
  ///
  /// This performs:
  /// - ATZ (Reset)
  /// - ATE0 (Echo Off)
  /// - ATL0 (Linefeeds Off)
  /// - ATSP0 (Auto protocol detection)
  ///
  /// ### Returns:
  /// - (`Future<void>`): Completes when initialization finishes.
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is not connected.
  Future<void> initializeAdapter() async {
    if (!isConnected) {
      throw StateError('Adapter is not connected.');
    }

    _isInitializingAdapter = true;

    try {
      await _sendCommand("ATZ", requestCode: 100);
      await Future.delayed(const Duration(milliseconds: 1000));

      final List<String> setupCommands = ["ATE0", "ATL0", "ATSP0"];

      for (final command in setupCommands) {
        await _sendCommand(command, requestCode: 100);
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      _isInitializingAdapter = false;
    }
  }

  /// Queries a specific SAE J1979 PID.
  ///
  /// Handles:
  /// - Command formatting
  /// - Response waiting
  /// - Hex extraction
  /// - Formula evaluation
  ///
  /// ### Parameters:
  /// - (`DetailedPID`): detailedPID - PID definition to query.
  ///
  /// ### Returns:
  /// - (`Future<dynamic>`): Decoded value (double, String, List, or raw bytes).
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is initializing.
  Future<dynamic> queryPID(DetailedPID detailedPID) async {
    if (_isInitializingAdapter) {
      throw StateError("Cannot query while adapter is initializing.");
    }

    final String command =
    protocol.buildDetailedPIDRequest(detailedPID);

    if (_pendingResponseCompleter != null &&
        !_pendingResponseCompleter!.isCompleted) {
      _pendingResponseCompleter!
          .completeError(Exception("Interrupted by new query"));
    }

    _pendingResponseCompleter = Completer<String>();
    _responseBuffer = '';

    try {
      await _sendCommand(command, requestCode: 400);

      final String rawResponse =
      await _pendingResponseCompleter!.future
          .timeout(const Duration(seconds: 5));

      if (rawResponse.contains("NO DATA") ||
          rawResponse.contains("?")) {
        return null;
      }

      final List<String> hexList =
      protocol.extractDataBytes(
        response: rawResponse,
        detailedPID: detailedPID,
      );

      if (hexList.isEmpty) return null;

      final List<int> dataBytes =
      hexList.map((hex) => int.parse(hex, radix: 16)).toList();

      switch (detailedPID.obd2QueryReturnType) {
        case QueryReturnValue.text:
          return String.fromCharCodes(dataBytes);

        case QueryReturnValue.composite:
          return _parseCompositePID(detailedPID, dataBytes);

        case QueryReturnValue.status:
          return dataBytes;

        case QueryReturnValue.double:
          return _evaluateMathExpression(detailedPID, dataBytes);
      }
    } catch (_) {
      return null;
    } finally {
      _pendingResponseCompleter = null;
    }
  }

  /// Evaluates the mathematical formula defined inside a PID.
  ///
  /// ### Parameters:
  /// - (`DetailedPID`): detailedPID - PID containing formula.
  /// - (`List<int>`): dataBytes - Raw ECU response bytes.
  ///
  /// ### Returns:
  /// - (`double?`): Calculated value or null if evaluation fails.
  double? _evaluateMathExpression(
      DetailedPID detailedPID,
      List<int> dataBytes) {
    try {
      String formula = detailedPID.formula;

      for (int index = 0; index < dataBytes.length; index++) {
        formula =
            formula.replaceAll('[$index]', dataBytes[index].toString());
      }

      final Expression expression =
      GrammarParser().parse(formula);

      return RealEvaluator(ContextModel())
          .evaluate(expression)
          .toDouble();
    } catch (_) {
      return null;
    }
  }

  /// Parses composite PIDs such as wideband oxygen sensor.
  ///
  /// ### Parameters:
  /// - (`DetailedPID`): detailedPID - PID definition.
  /// - (`List<int>`): bytes - Raw data bytes.
  ///
  /// ### Returns:
  /// - (`List<double>?`): Parsed composite values.
  List<double>? _parseCompositePID(
      DetailedPID detailedPID,
      List<int> bytes) {
    if (detailedPID.parameterID == "0124" &&
        bytes.length >= 4) {
      return [
        (256.0 * bytes[0] + bytes[1]) / 32768.0,
        (256.0 * bytes[2] + bytes[3]) / 8192.0
      ];
    }
    return null;
  }

  /// Sends a raw ASCII command to the ELM327 adapter.
  ///
  /// ### Parameters:
  /// - (`String`): command - Hex command string (e.g., "010C").
  /// - (`int`): requestCode - Internal classification.
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is not connected.
  Future<void> _sendCommand(
      String command, {
        required int requestCode,
      }) async {
    if (!isConnected) {
      throw StateError('Adapter is not connected.');
    }

    // _lastCommand = command;
    // _requestCode = requestCode;

    await write(utf8.encode('$command\r'));
  }

  /// Handles incoming transport data.
  ///
  /// Accumulates ASCII fragments and completes
  /// the pending request once the '>' prompt is detected.
  ///
  /// ### Parameters:
  /// - (`List<int>`): data - Incoming byte chunk.
  void _handleIncomingData(List<int> data) {
    final String newText =
    utf8.decode(data, allowMalformed: true);

    _responseBuffer += newText;

    if (_responseBuffer.contains('>')) {
      if (_pendingResponseCompleter != null &&
          !_pendingResponseCompleter!.isCompleted) {
        _pendingResponseCompleter!
            .complete(_responseBuffer);
      }
    }
  }
}