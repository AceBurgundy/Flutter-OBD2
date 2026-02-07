import 'dart:async';
import 'dart:convert';
import 'package:math_expressions/math_expressions.dart';
import '../../obd2.dart';

/// AT = Attention Command (Standard modem control prefix used by ELM327)
/// ECU = Engine Control Unit
/// PID = Parameter Identifier
/// ASCII = American Standard Code for Information Interchange

/// Defines the OBD-II request category used when communicating with the ECU.
enum OBDMode {
  /// Requests current powertrain diagnostic data (Mode 01).
  currentPowertrainData,
  /// Requests static vehicle information (Mode 09).
  vehicleInformation,
}

/// Low-level communication interface and **OBD-II engine**.
///
/// This abstract class handles the core logic of communicating with an
/// ELM327-compatible adapter. It manages the command queue, parses
/// raw ASCII responses, handles protocol initialization, and evaluates
/// mathematical formulas for PIDs.
abstract class AdapterOBD2 {
  /// Indicates whether the transport layer (Bluetooth/WiFi) is currently connected.
  bool get isConnected;

  /// A stream of raw bytes received from the physical adapter.
  Stream<List<int>> get incomingData;

  /// Writes raw bytes to the physical adapter.
  ///
  /// ### Parameters:
  /// - [data] (List<int>): The list of bytes (usually ASCII encoded) to send.
  Future<void> write(List<int> data);

  /// Disconnects the adapter and releases all transport resources.
  Future<void> disconnect();

  /// The diagnostic standard (e.g., SAE J1979) used to format commands and parse results.
  final DiagnosticStandard standard;

  /// A flag indicating if the adapter is currently running its initialization sequence.
  bool _isInitializingAdapter = false;

  /// The last command string sent to the ECU.
  /// Used for debugging context when a timeout or error occurs.
  String _latestCommand = '';

  /// A numeric code classifying the type of the last request.
  /// - 100: Initialization Command (AT commands)
  /// - 400: PID Data Request (Mode 01/09 commands)
  int _requestCode = 0;

  /// The internal buffer used to accumulate fragmented response data.
  String _responseBuffer = '';

  /// A completer used to signal the completion of a pending command.
  Completer<String>? _pendingResponseCompleter;

  /// Creates a new adapter instance.
  ///
  /// Automatically subscribes to the [incomingData] stream to handle responses.
  AdapterOBD2({required this.standard}) {
    // CRITICAL: Wire the stream here in the base class.
    // This ensures data is processed regardless of the transport implementation.
    incomingData.listen(_handleIncomingData);
  }

  /// Initializes the diagnostic adapter using standard AT commands.
  ///
  /// ### Throws:
  /// - (StateError): If the adapter is not connected.
  Future<void> initializeAdapter() async {
    if (!isConnected) throw StateError('Adapter is not connected.');

    _isInitializingAdapter = true;

    try {
      // 1. AT Z (Reset)
      await _sendCommand("ATZ", requestCode: 100);
      await Future.delayed(const Duration(milliseconds: 1000));

      // 2. Setup (Echo Off, Linefeeds Off, Auto Protocol)
      final List<String> initializationCommands = [
        "ATE0",
        "ATL0",
        "ATSP0"
      ];

      for (final String command in initializationCommands) {
        await _sendCommand(command, requestCode: 100);
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } catch (error, stackTrace) {
      logError(error, stackTrace, message: 'Failed to initialize OBD-II adapter.');
      rethrow;
    } finally {
      _isInitializingAdapter = false;
    }
  }

  /// Sends a PID request to the ECU and waits for the response.
  ///
  /// ### Parameters:
  /// - [detailedPID] (DetailedPID): The parameter to query.
  ///
  /// ### Returns:
  /// - (dynamic): The parsed value (double, String, or List). Returns `null` on failure.
  Future<dynamic> queryPID(DetailedPID detailedPID) async {
    if (_isInitializingAdapter) {
      throw StateError("Cannot query while adapter is initializing.");
    }

    final String command = standard.buildDetailedPIDRequest(detailedPID);

    // Cancel any hanging requests
    if (_pendingResponseCompleter != null && !_pendingResponseCompleter!.isCompleted) {
      _pendingResponseCompleter!.completeError(Exception("Interrupted by new query"));
    }

    _pendingResponseCompleter = Completer<String>();
    _responseBuffer = ''; // Clear buffer for fresh data

    try {
      await _sendCommand(command, requestCode: 400);

      String rawResponse;
      try {
        // Wait for response (Timeout set to 5s for slower ECUs)
        rawResponse = await _pendingResponseCompleter!.future.timeout(
            const Duration(seconds: 5)
        );
      } on TimeoutException {
        // Don't crash, just return null so the stream can retry
        logError(Exception("Timeout"), StackTrace.current,
            message: "ECU timed out on PID ${detailedPID.name}");
        return null;
      }

      if (rawResponse.contains("NO DATA") || rawResponse.contains("?")) {
        return null;
      }

      // Use the standard to extract relevant bytes
      final List<String> hexList = standard.extractDataBytes(
          response: rawResponse,
          detailedPID: detailedPID
      );

      if (hexList.isEmpty) return null;

      final List<int> dataBytes = hexList.map((hex) => int.parse(hex, radix: 16)).toList();

      switch (detailedPID.obd2QueryReturnType) {
        case OBD2QueryReturnValue.text:
          return String.fromCharCodes(dataBytes);
        case OBD2QueryReturnValue.composite:
          return _parseCompositePID(detailedPID, dataBytes);
        case OBD2QueryReturnValue.status:
          return dataBytes;
        case OBD2QueryReturnValue.double:
          return _evaluateMathExpression(detailedPID, dataBytes);
      }
    } catch (error, stackTrace) {
      logError(error, stackTrace, message: 'Failure querying PID ${detailedPID.name}.');
      return null;
    } finally {
      _pendingResponseCompleter = null;
    }
  }

  /// Evaluates the mathematical formula for a PID.
  ///
  /// **Note:** This method creates a fresh expression every time to avoid
  /// caching stale values when the byte data changes.
  double? _evaluateMathExpression(DetailedPID detailedPID, List<int> dataBytes) {
    try {
      String formula = detailedPID.formula;

      // Inject byte values into the formula
      for (int index = 0; index < dataBytes.length; index++) {
        formula = formula.replaceAll('[$index]', dataBytes[index].toString());
      }

      final Expression expression = GrammarParser().parse(formula);
      final ContextModel contextModel = ContextModel();
      return RealEvaluator(ContextModel()).evaluate(expression).toDouble();

    } catch (error, stackTrace) {
      logError(error, stackTrace, message: "Math evaluation failed for ${detailedPID.name}");
      return null;
    }
  }

  /// Parses special composite PIDs (like Wideband O2).
  List<double>? _parseCompositePID(DetailedPID detailedPID, List<int> bytes) {
    if (detailedPID.parameterID == "0124" && bytes.length >= 4) {
      return [
        (256.0 * bytes[0] + bytes[1]) / 32768.0,
        (256.0 * bytes[2] + bytes[3]) / 8192.0
      ];
    }
    return null;
  }

  /// Sends a raw command to the adapter.
  Future<void> _sendCommand(String command, {required int requestCode}) async {
    if (!isConnected) throw StateError('Adapter is not connected.');
    try {
      _latestCommand = command;
      _requestCode = requestCode;
      // Append Carriage Return (\r) as per ELM327 spec
      await write(utf8.encode('$command\r'));
    } catch (error, stackTrace) {
      logError(error, stackTrace, message: 'Failed to send command: $_latestCommand');
      rethrow;
    }
  }

  /// Internal handler for incoming data stream.
  void _handleIncomingData(List<int> data) {
    // Decode with allowMalformed to handle noisy cheap adapters
    final String newText = utf8.decode(data, allowMalformed: true);
    _responseBuffer += newText;

    // Check for the ELM327 prompt character '>'.
    // This indicates the device is done sending data and is waiting for a command.
    if (_responseBuffer.contains('>')) {
      if (_pendingResponseCompleter != null && !_pendingResponseCompleter!.isCompleted) {
        _pendingResponseCompleter!.complete(_responseBuffer);
      }
    }
  }
}