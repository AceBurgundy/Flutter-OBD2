import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:obd2/obd2.dart';
import 'functions.dart';

/// A state management class that handles OBD-II data streaming and Bluetooth connectivity.
class TelemetryProvider extends ChangeNotifier {
  /// The hardware adapter used for OBD-II communication.
  BluetoothAdapterOBD2? scanner;

  /// The active streaming session for telemetry data.
  TelemetrySession? _activeSession;

  /// The currently connected Bluetooth device.
  BluetoothDevice? connectedDevice;

  /// A timer used to throttle UI updates to prevent main-thread jank.
  Timer? _UIUpdateTimer;

  /// A flag indicating if new data has arrived since the last UI rebuild.
  bool _requiresUIUpdate = false;

  /// Indicates if the application is currently streaming data from the OBD-II adapter.
  bool isStreaming = false;

  /// Indicates if a Bluetooth connection attempt is currently in progress.
  bool isConnecting = false;

  /// Revolutions Per Minute: Current engine crank speed.
  double? engineRpm;

  /// Vehicle Speed: Current ground speed of the vehicle.
  double? vehicleSpeed;

  /// Coolant Temp: Current engine coolant temperature in Celsius.
  double? coolantTemperature;

  /// Throttle Position Sensor: Current throttle opening percentage (0-100%).
  double? throttlePosition;

  /// Calculated Engine Load: The percentage of peak available torque being used.
  double? engineLoad;

  /// Timing Advance: The ignition timing relative to Top Dead Center (TDC).
  double? timingAdvance;

  /// Initializes the provider and prepares data structures.
  ///
  /// ### Returns:
  /// - (`Future<void>`): A future that completes when initialization is done.
  Future<void> initializeProvider() async {
    try {
      notifyListeners();
    } catch (error, stack) {
      logError(error, stack, message: 'Failed to initialize vehicle data storage');
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
      scanner = BluetoothAdapterOBD2();
      await scanner!.connect(device);
      connectedDevice = device;
    } catch (error, stack) {
      logError(error, stack, message: 'Could not establish connection to ${device.platformName}');
    } finally {
      isConnecting = false;
      notifyListeners();
    }
  }

  /// Starts the high-priority telemetry stream and sets the polling interval.
  ///
  /// ### Usage:
  /// ```dart
  /// provider.startTelemetryStream();
  /// ```
  void startTelemetryStream() {
    if (scanner == null) {
      throw Exception("Scanner is null");
    }

    final telemetry = scanner!.protocol.telemetry;

    _activeSession = telemetry.stream(
      adapter: scanner!,
      pollIntervalMs: 30,
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
  }

  /// Internal handler for parsing raw OBD-II packets and triggering throttled updates.
  ///
  /// ### Parameters:
  /// - (`TelemetryData`) data: The raw packet received from the [TelemetrySession].
  void _processIncomingTelemetry(TelemetryData data) {
    final telemetry = scanner!.protocol.telemetry;

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

    _requiresUIUpdate = true;
    _runThrottledUpdate();
  }

  /// Throttles the [notifyListeners] call to ~30 FPS to maintain UI performance.
  void _runThrottledUpdate() {
    if (_UIUpdateTimer?.isActive ?? false) return;

    _UIUpdateTimer = Timer(const Duration(milliseconds: 33), () {
      if (_requiresUIUpdate) {
        notifyListeners();
        _requiresUIUpdate = false;
      }
    });
  }

  /// Terminates all active OBD-II streams and cancels the UI update timer.
  void stopTelemetryStream() {
    _activeSession?.stop();
    _UIUpdateTimer?.cancel();
    isStreaming = false;
    notifyListeners();
  }

  /// Properly closes resources when the provider is removed from the widget tree.
  @override
  void dispose() {
    stopTelemetryStream();
    _UIUpdateTimer?.cancel();
    super.dispose();
  }
}