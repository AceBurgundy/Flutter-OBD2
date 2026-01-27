import 'dart:async';

import '../../../../obd2.dart';
import '../../adapter_obd2.dart';

/// PID = Parameter Identifier
/// ECU = Engine Control Unit
///
/// Abstract base class for a telemetry mode.
///
/// A telemetry mode:
/// - Owns a set of PIDs
/// - Controls live streaming
/// - Allows one-time snapshot queries
///
/// Each diagnostic standard must provide its own concrete implementation.
abstract class TelemetryMode {
  /// Creates a telemetry mode bound to an adapter.
  ///
  /// ### Parameters:
  /// - (AdapterOBD2): Connected adapter instance.
  TelemetryMode();

  /// OBD-II service mode identifier (e.g. "01").
  static String get mode => throw UnimplementedError();

  /// Engine speed in revolutions per minute.
  DetailedPID get rpm;

  /// Vehicle speed.
  DetailedPID get speed;

  /// Engine coolant temperature.
  DetailedPID get coolantTemperature;

  /// Intake air temperature.
  DetailedPID get intakeAirTemperature;

  /// Throttle position percentage.
  DetailedPID get throttlePosition;

  /// Calculated engine load.
  DetailedPID get engineLoad;

  /// Mass air flow rate.
  DetailedPID get massAirFlow;

  /// Fuel level input.
  DetailedPID get fuelLevel;

  /// Intake manifold absolute pressure.
  DetailedPID get intakeManifoldPressure;

  /// Ignition timing advance.
  DetailedPID get timingAdvance;

  /// Barometric pressure.
  DetailedPID get barometricPressure;

  /// ECU control module voltage.
  DetailedPID get controlModuleVoltage;

  /// Engine oil temperature.
  DetailedPID get oilTemperature;

  /// Fuel consumption rate.
  DetailedPID get fuelRate;

  /// Ambient air temperature.
  DetailedPID get ambientAirTemperature;

  /// Fuel type identifier.
  DetailedPID get fuelType;

  /// Starts a live telemetry streaming session.
  TelemetrySession stream({
    required List<DetailedPID> detailedPIDs,
    required void Function(Map<DetailedPID, double>) onData,
    Duration pollInterval = const Duration(milliseconds: 300),
    required AdapterOBD2 adapter
  });

  /// Performs a one-time telemetry snapshot query.
  Future<Map<DetailedPID, double>> query({
    required List<DetailedPID> detailedPIDs,
    required AdapterOBD2 adapter
  });
}

/// Represents an active telemetry polling session.
///
/// A session manages:
/// - Periodic ECU polling
/// - Safe cancellation
///
/// Sessions must be explicitly stopped.
class TelemetrySession {
  /// Timer responsible for periodic polling.
  final Timer _pollingTimer;

  /// Creates a telemetry session.
  TelemetrySession(this._pollingTimer);

  /// Stops the telemetry session and releases resources.
  void stop() {
    _pollingTimer.cancel();
  }
}
