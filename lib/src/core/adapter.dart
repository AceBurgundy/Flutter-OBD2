import 'dart:async';
import 'dart:convert';

import 'package:math_expressions/math_expressions.dart';
import 'package:obd2/src/core/telemetry.dart';
import 'package:obd2/src/functions.dart';
import '../models.dart';
import 'diagnostic_standards/standard_abstract.dart';

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

/// Low-level communication interface for OBD-II adapters.
///
/// This class now **also contains the OBD-II engine** responsible
/// for sending commands, parsing ECU responses, and streaming telemetry.
abstract class AdapterOBD2 {
  /// Whether the adapter is currently connected and can send/receive data.
  bool get isConnected;

  /// Stream of raw bytes received from the adapter.
  Stream<List<int>> get incomingData;

  /// Sends raw ASCII-encoded bytes to the adapter.
  Future<void> write(List<int> data);

  /// Disconnects the adapter and cleans up resources.
  Future<void> disconnect();

  /// Diagnostic standard used to build requests and parse responses.
  final DiagnosticStandard diagnosticStandard;

  /// Queue of telemetry PIDs being streamed.
  final List<PIDInformation> _telemetryQueue = [];

  /// Controller emitting aggregated telemetry updates.
  final StreamController<Map<String, TelemetryValue>>
  _telemetryStreamController = StreamController.broadcast();

  /// Cached parsed expressions per PID for performance.
  final Map<String, Expression> _expressionCache = {};

  /// Indicates if the adapter is initializing (sending AT commands, etc.)
  bool _isInitializingAdapter = false;

  /// Last command sent to the ECU.
  String _latestCommand = '';

  /// Numeric identifier describing the last request type.
  int _requestCode = 0;

  AdapterOBD2({required this.diagnosticStandard});

  /// Stream of live telemetry updates.
  Stream<Map<String, TelemetryValue>> get telemetryStream =>
      _telemetryStreamController.stream;

  /// Initializes the diagnostic adapter using AT commands
  /// defined by the active diagnostic standard.
  Future<void> initializeAdapter() async {
    if (!isConnected) throw StateError('Adapter not connected.');
    _isInitializingAdapter = true;

    try {
      for (final String command in diagnosticStandard.initializationCommands) {
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

  /// Starts streaming telemetry for the given PIDs.
  ///
  /// The polling interval is dictated by the ECU to ensure live-synced data.
  ///
  /// ### Parameters:
  /// - (`List<PIDInformation>`): Telemetry PIDs to stream.
  void listenTelemetry({required List<PIDInformation> on}) {
    if (!isConnected) throw StateError('Adapter not connected.');
    _telemetryQueue
      ..clear()
      ..addAll(on);

    _startListening();
    _sendNextTelemetryRequest();
  }

  /// Stops telemetry streaming and clears internal state.
  void stopTelemetry() {
    _telemetryQueue.clear();
  }

  /// Internal: listens to incoming adapter data.
  void _startListening() {
    String responseBuffer = '';

    incomingData.listen((List<int> data) {
      responseBuffer += utf8.decode(data);

      if (responseBuffer.contains('>')) {
        _processRawResponse(responseBuffer);
        responseBuffer = '';
      }
    });
  }

  /// Internal: processes a raw ECU response string.
  void _processRawResponse(String rawResponse) {
    if (_isInitializingAdapter || _telemetryQueue.isEmpty) return;

    final String cleanedResponse = rawResponse
        .replaceAll(RegExp(r'[\n\r> ]'), '')
        .replaceAll('SEARCHING...', '');

    final PIDInformation parameterID = _telemetryQueue.removeAt(0);

    try {
      final TelemetryValue telemetryValue = _evaluatePIDResponse(
        parameterID,
        cleanedResponse,
      );

      _telemetryStreamController.add({parameterID.parameterID: telemetryValue});
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to process telemetry response.',
      );
    } finally {
      // push PID back to the queue for continuous streaming
      _telemetryQueue.add(parameterID);
      _sendNextTelemetryRequest();
    }
  }

  /// Internal: sends the next PID request in the telemetry queue.
  void _sendNextTelemetryRequest() {
    if (_telemetryQueue.isEmpty) return;

    final PIDInformation parameterID = _telemetryQueue.first;
    final String command =
    diagnosticStandard.buildParameterIDRequest(parameterID);

    _write(command, 400);
  }

  /// Evaluates a PID response into a typed telemetry value.
  TelemetryValue _evaluatePIDResponse(PIDInformation parameterID, String response) {
    final List<String> bytes = diagnosticStandard.extractDataBytes(
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

    // Currently only RPM is strictly typed, extendable for other telemetry
    if (parameterID.parameterID == '010C') {
      return RpmTelemetry(value);
    }

    throw UnsupportedError('Unsupported telemetry PID: ${parameterID.parameterID}');
  }

  /// Internal: writes a command to the adapter.
  Future<void> _write(String command, int requestCode) async {
    if (!isConnected) throw StateError('Adapter not connected.');

    try {
      _latestCommand = command;
      _requestCode = requestCode;

      await write(utf8.encode('$command\r\n'));
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
