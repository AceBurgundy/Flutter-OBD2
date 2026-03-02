import 'dart:async';
import 'package:flutter/material.dart';
import 'package:obd2/obd2.dart';
import 'functions.dart';

/// A state management class that handles OBD-II data streaming and Bluetooth connectivity.
class TelemetryProvider extends ChangeNotifier {
  /// The hardware adapter used for OBD-II communication.
  BluetoothAdapterOBD2? scanner;

  /// The active streaming session for telemetry data.
  TelemetrySession? _activeSession;

  /// The currently connected Bluetooth device ID.
  String? connectedDeviceId;

  /// A timer used to throttle UI updates to prevent main-thread jank.
  Timer? _displayUpdateTimer;

  /// A flag indicating if new data has arrived since the last UI rebuild.
  bool _requiresUIUpdate = false;

  /// Indicates if the application is currently streaming data from the OBD-II adapter.
  bool isStreaming = false;

  /// Indicates if a Bluetooth connection attempt is currently in progress.
  bool isConnecting = false;

  /// Revolutions Per Minute
  double? engineRpm;

  /// Vehicle Speed
  double? vehicleSpeed;

  /// Coolant Temp
  double? coolantTemperature;

  /// Throttle Position
  double? throttlePosition;

  /// Engine Load
  double? engineLoad;

  /// Timing Advance
  double? timingAdvance;

  Future<void> initializeProvider() async {
    try {
      notifyListeners();
    } catch (error, stack) {
      logError(error, stack,
          message: 'Failed to initialize vehicle data storage');
    }
  }

  /// Connect using deviceId instead of BluetoothDevice
  Future<void> connectToDevice(String deviceId) async {
    isConnecting = true;
    notifyListeners();

    try {
      if (isStreaming) {
        stopTelemetryStream();
      }

      await scanner?.disconnect();

      scanner = BluetoothAdapterOBD2();

      await scanner!.connect(deviceId);

      connectedDeviceId = deviceId;
    } catch (error, stack) {
      logError(
        error,
        stack,
        message: 'Could not establish connection to $deviceId',
      );
    } finally {
      isConnecting = false;
      notifyListeners();
    }
  }

  void startTelemetryStream() {
    if (scanner == null) {
      throw Exception("Scanner is null");
    }

    final telemetry = scanner!.protocol.telemetry;

    _activeSession = telemetry.stream(
      detailedPIDs: [
        Telemetry.rpm,
        Telemetry.speed,
        Telemetry.coolantTemperature,
        Telemetry.throttlePosition,
        Telemetry.engineLoad,
        Telemetry.intakeAirTemperature,
        Telemetry.timingAdvance,
      ],
      onData: _processIncomingTelemetry,
    );

    isStreaming = true;
    notifyListeners();
  }

  void _processIncomingTelemetry(TelemetryData data) {
    if (data.hasData(Telemetry.rpm)) {
      engineRpm = data.get(Telemetry.rpm);
    }

    if (data.hasData(Telemetry.speed)) {
      vehicleSpeed = data.get(Telemetry.speed);
    }

    if (data.hasData(Telemetry.coolantTemperature)) {
      coolantTemperature = data.get(Telemetry.coolantTemperature);
    }

    if (data.hasData(Telemetry.throttlePosition)) {
      throttlePosition = data.get(Telemetry.throttlePosition);
    }

    if (data.hasData(Telemetry.engineLoad)) {
      engineLoad = data.get(Telemetry.engineLoad);
    }

    if (data.hasData(Telemetry.timingAdvance)) {
      timingAdvance = data.get(Telemetry.timingAdvance);
    }

    _requiresUIUpdate = true;
    _runThrottledUpdate();
  }

  void _runThrottledUpdate() {
    if (_displayUpdateTimer?.isActive ?? false) return;

    _displayUpdateTimer =
        Timer(const Duration(milliseconds: 33), () {
      if (_requiresUIUpdate) {
        notifyListeners();
        _requiresUIUpdate = false;
      }
    });
  }

  void stopTelemetryStream() {
    _activeSession?.stop();
    _displayUpdateTimer?.cancel();
    isStreaming = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTelemetryStream();
    _displayUpdateTimer?.cancel();
    scanner?.disconnect();
    super.dispose();
  }
}