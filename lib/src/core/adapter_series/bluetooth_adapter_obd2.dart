import 'dart:async';
import 'dart:convert';

import 'package:math_expressions/math_expressions.dart';
import 'package:obd2/src/core/telemetry.dart';
import 'package:obd2/src/functions.dart';

import '../../models.dart';
import '../adapter.dart';
import '../diagnostic_standards/standard_abstract.dart';

/// AT = Attention Command (ELM327 adapter control commands)
/// ECU = Engine Control Unit
/// PID = Parameter Identifier (OBD-II telemetry code)
/// BLE = Bluetooth Low Energy

/// Defines the operational mode used when communicating with the ECU.
///
/// Each mode corresponds to a standardized OBD-II request category.
enum OBDMode {
  /// Requests real-time powertrain data such as
  /// engine speed, vehicle speed, and coolant temperature.
  currentPowertrainData,

  /// Requests static vehicle information such as
  /// VIN, calibration identifiers, and ECU metadata.
  vehicleInformation,
}

/// Adapter-based OBD-II engine that communicates with the ECU
/// and streams live telemetry.
///
/// This class now extends the [AdapterOBD2] abstraction, so any
/// transport layer (Bluetooth, USB, etc.) can be used.
///
/// Responsibilities:
/// - Initialize the adapter using AT commands
/// - Queue and stream multiple PIDs
/// - Parse and evaluate telemetry formulas
/// - Emit typed telemetry values
class OBD2 {
  /// Underlying OBD-II transport adapter.
  final AdapterOBD2 _adapter;

  /// Diagnostic standard used for building PID requests
  /// and parsing ECU responses.
  final DiagnosticStandard _diagnosticStandard;

  /// Last command sent to the ECU.
  String _latestCommand = '';

  /// Numeric identifier describing the last request type.
  int _requestCode = 0;

  /// Indicates whether adapter initialization is in progress.
  bool _isInitializingAdapter = false;

  /// Queue of telemetry PIDs currently being streamed.
  final List<PIDInformation> _telemetryQueue = [];

  /// Controller emitting aggregated telemetry updates.
  final StreamController<Map<String, TelemetryValue>>
  _telemetryStreamController = StreamController.broadcast();

  /// Cached parsed expressions per PID for performance.
  final Map<String, Expression> _expressionCache = {};

  OBD2({
    required AdapterOBD2 adapter,
    required DiagnosticStandard diagnosticStandard,
  })  : _adapter = adapter,
        _diagnosticStandard = diagnosticStandard;

  /// Stream of live telemetry updates.
  Stream<Map<String, TelemetryValue>> get telemetryStream =>
      _telemetryStreamController.stream;

  /// Connects to the adapter and automatically initializes it.
  ///
  /// ### Throws:
  /// - (`StateError`) If the adapter is not connected.
  /// - (`Exception`) If the connection or initialization fails.
  Future<void> connect() async {
    if (!_adapter.isConnected) {
      throw StateError('Adapter is not connected. Call connect() on the adapter first.');
    }

    await _initializeAdapter();
    _startListening();
  }

  /// Initializes the diagnostic adapter using AT commands
  /// defined by the active diagnostic standard.
  Future<void> _initializeAdapter() async {
    _isInitializingAdapter = true;

    try {
      for (final String command in _diagnosticStandard.initializationCommands) {
        await _write(command, 100);
        await Future.delayed(const Duration(milliseconds: 150));
      }
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to initialize diagnostic adapter.',
      );
      rethrow;
    } finally {
      _isInitializingAdapter = false;
    }
  }

  /// Starts streaming telemetry for the given PIDs and returns
  /// a single combined stream for immediate subscription.
  ///
  /// ### Parameters:
  /// - (`List<PIDInformation>`): List of telemetry PIDs to stream.
  ///
  /// ### Returns:
  /// - (`Stream<Map<String, TelemetryValue>>`): Live telemetry updates.
  ///
  /// ### Usage:
  /// ```dart
  /// scanner.streamTelemetry(on: [rpm, coolantTemp]).listen((data) {
  ///   print('RPM: ${data[rpm]?.value}');
  /// });
  /// ```
  Stream<Map<String, TelemetryValue>> streamTelemetry({ required List<PIDInformation> on }) {
    if (on.isEmpty) {
      throw Exception("No telemetry PID's provided");
    }

    _telemetryQueue..clear()..addAll(on);
    _sendNextTelemetryRequest();

    return _telemetryStreamController.stream;
  }

  /// Begins listening to adapter notifications.
  void _startListening() {
    String responseBuffer = '';

    _adapter.incomingData.listen((List<int> data) {
      responseBuffer += utf8.decode(data);

      if (responseBuffer.contains('>')) {
        _processRawResponse(responseBuffer);
        responseBuffer = '';
      }
    });
  }

  /// Stops telemetry streaming and clears internal state.
  void stop() {
    _telemetryQueue.clear();
  }

  /// Processes a raw ECU response string.
  void _processRawResponse(String rawResponse) {
    if (_isInitializingAdapter || _telemetryQueue.isEmpty) return;

    final String cleanedResponse = rawResponse
        .replaceAll(RegExp(r'[\n\r> ]'), '')
        .replaceAll('SEARCHING...', '');

    final PIDInformation parameterID = _telemetryQueue.removeAt(0);

    try {
      final TelemetryValue telemetryValue =
      _evaluatePIDResponse(parameterID, cleanedResponse);

      _telemetryStreamController.add({parameterID.parameterID: telemetryValue});
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to process telemetry response.',
      );
    } finally {
      _telemetryQueue.add(parameterID);
      _sendNextTelemetryRequest();
    }
  }

  /// Sends the next PID request in the telemetry queue.
  void _sendNextTelemetryRequest() {
    if (_telemetryQueue.isEmpty) return;

    final PIDInformation parameterID = _telemetryQueue.first;
    final String command =
    _diagnosticStandard.buildParameterIDRequest(parameterID);

    _write(command, 400);
  }

  /// Evaluates a PID response into a typed telemetry value.
  TelemetryValue _evaluatePIDResponse(
      PIDInformation parameterID, String response) {
    final List<String> bytes = _diagnosticStandard.extractDataBytes(
      response: response,
      pIDInfo: parameterID,
    );

    String formula = parameterID.formula;

    for (int index = 0; index < bytes.length; index++) {
      formula = formula.replaceAll(
        '[$index]',
        int.parse(bytes[index], radix: 16).toString(),
      );
    }

    final Expression expression = _expressionCache.putIfAbsent(
      parameterID.parameterID,
          () => GrammarParser().parse(formula),
    );

    final double value = RealEvaluator().evaluate(expression).toDouble();

    // Currently only RPM is typed as a TelemetryValue child.
    if (parameterID.parameterID == '010C') {
      return RpmTelemetry(value);
    }

    throw UnsupportedError(
        'Unsupported telemetry PID: ${parameterID.parameterID}');
  }

  /// Sends a raw command to the adapter.
  ///
  /// ### Parameters:
  /// - (`String command`): The ASCII command string.
  /// - (`int requestCode`): Internal request identifier.
  ///
  /// ### Throws:
  /// - (`StateError`) If the adapter is not connected.
  /// - (`Exception`) If the write operation fails.
  Future<void> _write(String command, int requestCode) async {
    if (!_adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    _latestCommand = command;
    _requestCode = requestCode;

    try {
      await _adapter.write(utf8.encode('$command\r\n'));
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to send command to diagnostic adapter.',
      );
      rethrow;
    }
  }
}
