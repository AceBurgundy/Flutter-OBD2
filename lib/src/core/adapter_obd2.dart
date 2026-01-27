import 'dart:async';
import 'dart:convert';

import 'package:math_expressions/math_expressions.dart';
import 'package:obd2/src/functions.dart';

import '../models.dart';
import 'diagnostic_standards/standard_abstract.dart';

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
  bool _isInitializingAdapter = false;

  /// Last command sent to the ECU.
  String _latestCommand = '';

  /// Numeric identifier describing the last request type.
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
      for (final String command in standard.initializationCommands) {
        await _sendCommand(command, requestCode: 100);
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to initialize OBD-II adapter.',
      );
      rethrow;
    } finally {
      _isInitializingAdapter = false;
    }
  }

  /// Sends a PID request and waits for its ECU response.
  ///
  /// ### Parameters:
  /// - (`DetailedPID`): PID to query.
  ///
  /// ### Returns:
  /// - (`double`): Parsed telemetry value.
  ///
  /// ### Throws:
  /// - (`TimeoutException`): If ECU does not respond.
  Future<double> queryPID(DetailedPID detailedPID) async {
    final String command = standard.buildDetailedPIDRequest(
      detailedPID,
    );

    _pendingResponseCompleter = Completer<String>();

    try {
      await _sendCommand(command, requestCode: 400);

      final String rawResponse = await _pendingResponseCompleter!.future
          .timeout(const Duration(seconds: 2));

      return _evaluatePIDResponse(detailedPID, rawResponse);
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Timeout or failure while querying PID.',
      );
      rethrow;
    } finally {
      _pendingResponseCompleter = null;
    }
  }

  /// Evaluates an ECU response into a numeric telemetry value.
  double _evaluatePIDResponse(DetailedPID detailedPID, String rawResponse) {
    final String cleanedResponse = rawResponse
        .replaceAll(RegExp(r'[\n\r> ]'), '')
        .replaceAll('SEARCHING...', '');

    final List<String> bytes = standard.extractDataBytes(
      response: cleanedResponse,
      detailedPID: detailedPID,
    );

    String formula = detailedPID.formula;

    for (int index = 0; index < bytes.length; index++) {
      formula = formula.replaceAll(
        '[$index]',
        int.parse(bytes[index], radix: 16).toString(),
      );
    }

    final Expression expression = _expressionCache.putIfAbsent(
      detailedPID.parameterID,
      () => GrammarParser().parse(formula),
    );

    return RealEvaluator().evaluate(expression).toDouble();
  }

  /// Sends a raw command to the adapter.
  ///
  /// ### Parameters:
  /// - (`String`): Command string.
  /// - (`int`): Request classification code.
  Future<void> _sendCommand(String command, {required int requestCode}) async {
    if (!isConnected) {
      throw StateError('Adapter is not connected.');
    }

    try {
      _latestCommand = command;
      _requestCode = requestCode;

      await write(utf8.encode('$command\r\n'));
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to send command to OBD-II adapter.',
      );
      rethrow;
    }
  }

  /// Internal hook to be called by transport implementations
  /// when new raw data arrives from the adapter.
  void handleIncomingData(List<int> data) {
    _responseBuffer += utf8.decode(data);

    if (_responseBuffer.contains('>') && _pendingResponseCompleter != null && !_pendingResponseCompleter!.isCompleted) {
      _pendingResponseCompleter!.complete(_responseBuffer);
      _responseBuffer = '';
    }
  }
}
