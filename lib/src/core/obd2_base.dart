import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:obd2/src/core/telemetry.dart';
import 'package:obd2/src/functions.dart';

import '../models.dart';
import 'bluetooth_service.dart';
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

/// High-level OBD-II controller responsible for:
/// - Managing Bluetooth communication
/// - Initializing the diagnostic adapter
/// - Streaming live telemetry
/// - Parsing and evaluating ECU responses
class BluetoothOBD2 {
  /// Underlying Bluetooth communication service.
  final OBD2BluetoothService _bluetoothService;

  /// Diagnostic standard used to build requests and parse responses.
  final DiagnosticStandard _diagnosticStandard;

  /// Currently connected Bluetooth device.
  BluetoothDevice? _connectedDevice;

  /// Last command sent to the ECU.
  String _latestCommand = '';

  /// Numeric identifier describing the last request type.
  int _requestCode = 0;

  /// Indicates whether adapter initialization is in progress.
  bool _isInitializingAdapter = false;

  /// Active BLE notification stream subscription.
  StreamSubscription<List<int>>? _notificationSubscription;

  /// Queue of telemetry PIDs currently being streamed.
  final List<PIDInformation> _telemetryQueue = [];

  /// Controller emitting aggregated telemetry updates.
  final StreamController<Map<String, TelemetryValue>>
  _telemetryStreamController = StreamController.broadcast();

  /// Cached parsed expressions per PID for performance.
  final Map<String, Expression> _expressionCache = {};

  BluetoothOBD2({
    required OBD2BluetoothService bluetoothService,
    required DiagnosticStandard diagnosticStandard,
  }) : _bluetoothService = bluetoothService,
       _diagnosticStandard = diagnosticStandard;

  /// Stream of live telemetry updates.
  Stream<Map<String, TelemetryValue>> get telemetryStream =>
      _telemetryStreamController.stream;

  /// Sets the active Bluetooth connection.
  set connection(BluetoothDevice device) {
    _connectedDevice = device;
  }

  /// Returns the currently connected Bluetooth device.
  BluetoothDevice get connection {
    if (_connectedDevice == null || !_bluetoothService.isConnected) {
      throw StateError('Bluetooth device is not connected.');
    }
    return _connectedDevice!;
  }

  /// Ensures an active Bluetooth connection exists.
  void _validateConnection() {
    if (!_bluetoothService.isConnected || _connectedDevice == null) {
      throw StateError('Bluetooth connection lost.');
    }
  }

  /// Initializes the diagnostic adapter using AT commands
  /// defined by the active diagnostic standard.
  Future<void> initializeAdapter() async {
    _validateConnection();
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

  /// Starts streaming telemetry for the given PIDs.
  ///
  /// The polling interval is dictated by the ECU response timing,
  /// ensuring live vehicle-synchronized data.
  ///
  /// ### Parameters:
  /// - (`List<PIDInformation>`): List of telemetry PIDs to stream.
  void listenTelemetry({required List<PIDInformation> on}) {
    _validateConnection();
    _telemetryQueue
      ..clear()
      ..addAll(on);

    startListening();
    _sendNextTelemetryRequest();
  }

  /// Begins listening to BLE notifications from the ECU.
  void startListening() {
    _validateConnection();

    String responseBuffer = '';

    _notificationSubscription = _bluetoothService
        .writeCharacteristic
        ?.lastValueStream
        .listen((List<int> data) {
          responseBuffer += utf8.decode(data);

          if (responseBuffer.contains('>')) {
            _processRawResponse(responseBuffer);
            responseBuffer = '';
          }
        });
  }

  /// Stops telemetry streaming and clears internal state.
  void stop() {
    _notificationSubscription?.cancel();
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
      _telemetryQueue.add(parameterID);
      _sendNextTelemetryRequest();
    }
  }

  /// Sends the next PID request in the telemetry queue.
  void _sendNextTelemetryRequest() {
    if (_telemetryQueue.isEmpty) return;

    final PIDInformation parameterID = _telemetryQueue.first;
    final String command = _diagnosticStandard.buildParameterIDRequest(parameterID);

    _write(command, 400);
  }

  /// Evaluates a PID response into a typed telemetry value.
  TelemetryValue _evaluatePIDResponse(PIDInformation parameterID, String response) {
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

    if (parameterID.parameterID == '010C') {
      return RpmTelemetry(value);
    }

    throw UnsupportedError('Unsupported telemetry PID: ${parameterID.parameterID}');
  }

  /// Sends a command to the OBD-II adapter.
  Future<void> _write(String command, int requestCode) async {
    _validateConnection();

    try {
      _latestCommand = command;
      _requestCode = requestCode;

      await _bluetoothService.writeCharacteristic?.write(
        utf8.encode('$command\r\n'),
      );
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
