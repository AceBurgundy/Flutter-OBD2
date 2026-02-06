import 'dart:async';
import 'dart:convert';

import 'package:math_expressions/math_expressions.dart';
import '../../obd2.dart';

/// AT = Attention Command (ELM327 adapter control command)
/// ECU = Engine Control Unit
/// PID = Parameter Identifier
/// BLE = Bluetooth Low Energy

/// Defines the OBD-II request category used when communicating with the ECU.
///
/// Each mode maps to a standardized OBD-II service.
enum OBDMode {
  /// Requests **current powertrain diagnostic data** (Mode 01).
  ///
  /// Examples:
  /// - Engine RPM
  /// - Vehicle speed
  /// - Coolant temperature
  currentPowertrainData,

  /// Requests **static vehicle information** (Mode 09).
  ///
  /// Examples:
  /// - Vehicle Identification Number (VIN)
  /// - ECU calibration identifiers
  vehicleInformation,
}

/// Low-level communication interface and **OBD-II engine**.
///
/// This class:
/// - Sends commands to the ECU
/// - Waits for responses
/// - Parses telemetry values
///
/// Subclasses handle **transport mechanics** (BLE, USB, etc.).
/// This class handles **protocol semantics**.
abstract class AdapterOBD2 {
  /// Indicates whether the adapter is currently connected.
  bool get isConnected;

  /// Stream of raw ASCII bytes received from the adapter.
  Stream<List<int>> get incomingData;

  /// Writes raw ASCII-encoded bytes to the adapter.
  Future<void> write(List<int> data);

  /// Disconnects the adapter and releases all resources.
  Future<void> disconnect();

  /// Diagnostic standard used to build commands and parse responses.
  final DiagnosticStandard standard;

  /// Cached parsed math expressions per PID for performance.
  final Map<String, Expression> _expressionCache = {};

  /// Indicates whether adapter initialization is currently running.
  ///
  /// Used to block new PID queries while the adapter is resetting.
  bool _isInitializingAdapter = false;

  /// Last command sent to the ECU.
  ///
  /// Used for debugging context when a timeout or error occurs.
  String _latestCommand = '';

  /// Numeric identifier describing the last request type.
  ///
  /// - 100: Initialization Command
  /// - 400: PID Data Request
  int _requestCode = 0;

  /// Internal response buffer for assembling ECU replies.
  String _responseBuffer = '';

  /// Completer waiting for the current ECU response.
  Completer<String>? _pendingResponseCompleter;

  AdapterOBD2({required this.standard});

  /// Initializes the diagnostic adapter using AT commands.
  ///
  /// This method is automatically called after a successful connection.
  ///
  /// ### Throws:
  /// - (`StateError`): If the adapter is not connected.
  /// - (`Exception`): If initialization fails.
  Future<void> initializeAdapter() async {
    if (!isConnected) {
      throw StateError('Adapter is not connected.');
    }

    _isInitializingAdapter = true;

    try {
      // Standard initialization sequence
      // 1. AT Z (Reset)
      // 2. AT E0 (Echo Off)
      // 3. AT L0 (Linefeeds Off)
      // 4. AT SP0 (Auto Protocol)
      final List<String> initializationCommands = [
        "ATZ",
        "ATE0",
        "ATL0",
        "ATSP0"
      ];

      for (final String command in initializationCommands) {
        await _sendCommand(command, requestCode: 100);
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to initialize OBD-II adapter. Last command: $_latestCommand',
      );
      rethrow;
    } finally {
      _isInitializingAdapter = false;
    }
  }

  /// Sends a PID request and waits for its ECU response.
  ///
  /// The return type depends on [detailedPID.returnType].
  ///
  /// ### Parameters:
  /// - (`DetailedPID`): PID to query.
  ///
  /// ### Returns:
  /// - (`dynamic?`): Parsed data (Double, String, or Map). **Returns null** if vehicle has no data.
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is initializing.
  /// - (`TimeoutException`): If ECU does not respond.
  Future<dynamic> queryPID(DetailedPID detailedPID) async {
    if (_isInitializingAdapter) {
      throw StateError(
          "Cannot query PID ${detailedPID.name} while adapter is initializing.");
    }

    final String command = standard.buildDetailedPIDRequest(detailedPID);
    _pendingResponseCompleter = Completer<String>();

    try {
      await _sendCommand(command, requestCode: 400);

      // Wrapping the wait in a specific try-catch for Timeouts.
      String rawResponse;
      try {
        rawResponse = await _pendingResponseCompleter!.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // If the ECU doesn't reply in 2s, we return null (No Data)
        // instead of throwing an exception that breaks the loop.
        logError(
            Exception("Timeout"),
            StackTrace.current,
            message: "ECU timed out on PID ${detailedPID.parameterID} (${detailedPID.name})"
        );
        return null;
      }

      if (rawResponse.contains("NO DATA") || rawResponse.contains("?") == true) {
        return null;
      }

      final String cleanedResponse = rawResponse
          .replaceAll(RegExp(r'[\n\r> ]'), '')
          .replaceAll('SEARCHING...', '');

      final List<int> dataBytes = standard
          .extractDataBytes(
        response: cleanedResponse,
        detailedPID: detailedPID,
      )
          .map((hex) => int.parse(hex, radix: 16))
          .toList();

      if (dataBytes.isEmpty) return null;

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
      logError(
        error,
        stackTrace,
        message: 'Failure querying PID ${detailedPID.parameterID}. Last Command: $_latestCommand',
      );
      return null;
    } finally {
      _pendingResponseCompleter = null;
    }
  }

  /// Evaluates standard numeric PIDs using the math expression engine.
  ///
  /// ### Parameters:
  /// - (`DetailedPID`): The PID containing the formula.
  /// - (`List<int>`): The raw data bytes from the ECU.
  ///
  /// ### Returns:
  /// - (`double?`): The physical value, or **null** if evaluation fails.
  double? _evaluateMathExpression(DetailedPID detailedPID, List<int> dataBytes) {
    try {
      String formula = detailedPID.formula;

      // Replace placeholders [0], [1] with actual byte values
      for (int index = 0; index < dataBytes.length; index++) {
        formula = formula.replaceAll(
          '[$index]',
          dataBytes[index].toString(),
        );
      }

      // Check Cache
      Expression? expression = _expressionCache[detailedPID.parameterID];

      // Parse if not cached
      if (expression == null) {
        expression = GrammarParser().parse(formula);
        _expressionCache[detailedPID.parameterID] = expression;
      }

      // Evaluate
      final ContextModel contextModel = ContextModel();
      return RealEvaluator(contextModel).evaluate(expression).toDouble();

    } catch (error, stackTrace) {
      logError(
          error,
          stackTrace,
          message: "Math evaluation failed for ${detailedPID.parameterID}"
      );
      return null;
    }
  }

  /// Handles special composite PIDs that return multiple values.
  ///
  /// ### Parameters:
  /// - (`DetailedPID`): The PID definition.
  /// - (`List<int>`): The raw bytes.
  ///
  /// ### Returns:
  /// - (`List<double>?`): A list of values, or null if bytes are insufficient.
  List<double>? _parseCompositePID(DetailedPID pid, List<int> bytes) {
    // Specific logic for Wideband O2 (PID 0124)
    if (pid.parameterID == "0124" && bytes.length >= 4) {
      // Byte A, B = Lambda
      double lambda = (256.0 * bytes[0] + bytes[1]) / 32768.0;

      // Byte C, D = Voltage
      double voltage = (256.0 * bytes[2] + bytes[3]) / 8192.0;

      return [lambda, voltage];
    }

    return null;
  }

  /// Sends a raw command to the adapter.
  ///
  /// ### Parameters:
  /// - (`String`): Command string.
  /// - (`int`): Request classification code (100=Init, 400=Query).
  Future<void> _sendCommand(String command, {required int requestCode}) async {
    if (!isConnected) {
      throw StateError('Adapter is not connected.');
    }

    try {
      _latestCommand = command;
      _requestCode = requestCode;

      // Append Carriage Return (\r) as required by ELM327 protocol
      await write(utf8.encode('$command\r'));
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to send command: $_latestCommand',
      );
      rethrow;
    }
  }

  /// Internal hook to be called by transport implementations
  /// when new raw data arrives from the adapter.
  ///
  /// ### Parameters:
  /// - (`List<int>`): Raw bytes received from the socket/bluetooth stream.
  void handleIncomingData(List<int> data) {
    _responseBuffer += utf8.decode(data);

    // ELM327 ends responses with the '>' character prompt.
    if (_responseBuffer.contains('>') &&
        _pendingResponseCompleter != null &&
        !_pendingResponseCompleter!.isCompleted) {
      _pendingResponseCompleter!.complete(_responseBuffer);
      _responseBuffer = '';
    }
  }
}