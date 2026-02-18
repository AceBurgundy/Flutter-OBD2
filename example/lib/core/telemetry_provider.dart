import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:obd2/obd2.dart';

import 'functions.dart';

/// BLE: Bluetooth Low Energy
/// OBD: On-Board Diagnostics
/// RPM: Revolutions Per Minute
/// TPS: Throttle Position Sensor
/// CEL: Calculated Engine Load
/// IAT: Intake Air Temperature
/// TA: Timing Advance
/// DTC: Diagnostic Trouble Codes
/// ECU: Engine Control Unit
/// PID: Parameter Identification

/// A state management class that handles OBD-II data streaming and Bluetooth connectivity.
class TelemetryProvider extends ChangeNotifier {
  /// The hardware adapter used for OBD-II communication.
  BluetoothAdapterOBD2? scanner;

  /// The active streaming session for telemetry data.
  TelemetrySession? _telemetrySession;

  /// The currently connected Bluetooth device.
  BluetoothDevice? connectedDevice;

  /// The logic handler for Society of Automotive Engineers (SAE) J1979 standards.
  final SaeJ1979 _saeJ1979 = SaeJ1979();

  /// Indicates if the application is currently streaming data from the OBD-II adapter.
  bool isStreaming = false;

  /// Indicates if a Bluetooth connection attempt is currently in progress.
  bool isConnecting = false;

  /// Current Engine Revolutions Per Minute.
  double? engineRpm;

  /// Current vehicle speed retrieved via OBD-II.
  double? vehicleSpeed;

  /// Current engine coolant temperature in Celsius.
  double? coolantTemperature;

  /// Current throttle position percentage (0-100%).
  double? throttlePosition;

  /// The engine load percentage.
  double? engineLoad;

  /// The ignition timing advance relative to Top Dead Center (TDC).
  double? timingAdvance;

  /// Initializes the provider by loading vehicle data from Hive storage.
  ///
  /// ### Returns:
  /// - (`Future<void>`): A future that completes when initialization is done.
  ///
  /// ### Throws:
  /// - (Exception): If [MainVehicle.initialize] fails.
  Future<void> initializeProvider() async {
    try {
      notifyListeners();
    } catch (error, stack) {
      logError(error, stack, message: 'Failed to initialize vehicle data storage.');
    }
  }

  /// Connects to a specific Bluetooth OBD-II dongle.
  ///
  /// ### Parameters:
  /// - (`BluetoothDevice`) device: The device selected from the paired list.
  ///
  /// ### Returns:
  /// - (`Future<void>`): A future that completes when the connection is established.
  Future<void> connectToDevice(BluetoothDevice device) async {
    isConnecting = true;
    notifyListeners();

    try {
      if (isStreaming) {
        stopTelemetryStream();
      }
      await scanner?.disconnect();

      scanner = BluetoothAdapterOBD2(standard: _saeJ1979);
      await scanner!.connect(device);
      connectedDevice = device;
    } catch (error, stack) {
      logError(error, stack, message: 'Could not establish connection to ${device.platformName}.');
    } finally {
      isConnecting = false;
      notifyListeners();
    }
  }

  /// Starts the high-priority telemetry stream and mobile sensor tracking.
  ///
  /// ### Usage:
  /// ```dart
  /// provider.startTelemetryStream();
  /// ```
  void startTelemetryStream() {
    if (scanner == null || !scanner!.isConnected) return;

    try {
      // Start OBD Stream
      final telemetry = _saeJ1979.telemetry;
      _telemetrySession = telemetry.stream(
        adapter: scanner!,
        pollIntervalMs: 10,
        detailedPIDs: [
          telemetry.rpm,
          telemetry.speed,
          telemetry.coolantTemperature,
          telemetry.throttlePosition,
          telemetry.engineLoad,
          telemetry.intakeAirTemperature,
          telemetry.timingAdvance,
        ],
        onData: _processIncomingTelemetry,
      );

      isStreaming = true;
      notifyListeners();
    } catch (error, stack) {
      logError(error, stack, message: 'Failed to start live data streaming.');
      stopTelemetryStream();
    }
  }

  /// Internal handler for parsing raw OBD-II packets into class fields.
  ///
  /// ### Parameters:
  /// - (`TelemetryData`) data: The raw packet received from the [TelemetrySession].
  void _processIncomingTelemetry(TelemetryData data) {
    final telemetry = _saeJ1979.telemetry;

    if (data.hasData(telemetry.rpm) == true) {
      engineRpm = data.get(telemetry.rpm);
    }

    if (data.hasData(telemetry.speed) == true) {
      vehicleSpeed = data.get(telemetry.speed);
    }

    if (data.hasData(telemetry.coolantTemperature) == true) {
      coolantTemperature = data.get(telemetry.coolantTemperature);
    }

    if (data.hasData(telemetry.throttlePosition) == true) {
      throttlePosition = data.get(telemetry.throttlePosition);
    }

    if (data.hasData(telemetry.engineLoad) == true) {
      engineLoad = data.get(telemetry.engineLoad);
    }

    if (data.hasData(telemetry.timingAdvance) == true) {
      timingAdvance = data.get(telemetry.timingAdvance);
    }

    notifyListeners();
  }

  /// Terminates all active OBD-II and mobile sensor streams.
  void stopTelemetryStream() {
    try {
      _telemetrySession?.stop();
      isStreaming = false;
      notifyListeners();
    } catch (error, stack) {
      logError(error, stack, message: 'Error encountered while stopping streams.');
    }
  }

  /// Properly closes resources when the provider is removed from the widget tree.
  @override
  void dispose() {
    stopTelemetryStream();
    super.dispose();
  }
}