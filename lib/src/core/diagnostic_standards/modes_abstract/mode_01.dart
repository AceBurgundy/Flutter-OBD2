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
  DetailedPID<double> get rpm;

  /// Vehicle speed.
  DetailedPID<double> get speed;

  /// Vehicle odometer.
  DetailedPID<double> get odometer;

  /// Engine coolant temperature.
  DetailedPID<double> get coolantTemperature;

  /// Intake air temperature.
  DetailedPID<double> get intakeAirTemperature;

  /// Throttle position percentage.
  DetailedPID<double> get throttlePosition;

  /// Calculated engine load.
  DetailedPID<double> get engineLoad;

  /// Mass air flow rate.
  DetailedPID<double> get massAirFlow;

  /// Fuel level input.
  DetailedPID<double> get fuelLevel;

  /// Intake manifold absolute pressure.
  DetailedPID<double> get intakeManifoldPressure;

  /// Ignition timing advance.
  DetailedPID<double> get timingAdvance;

  /// Data that can be extracted for AFR.
  DetailedPID<List<double>> get lambdaBank1Sensor1;

  /// Barometric pressure.
  DetailedPID<double> get barometricPressure;

  /// ECU control module voltage.
  DetailedPID<double> get controlModuleVoltage;

  /// Engine oil temperature.
  DetailedPID<double> get oilTemperature;

  /// Fuel consumption rate.
  DetailedPID<double> get fuelRate;

  /// Ambient air temperature.
  DetailedPID<double> get ambientAirTemperature;

  /// Fuel type identifier.
  DetailedPID<String> get fuelType;

  /// Starts a live telemetry streaming session.
  ///
  /// ### Parameters:
  /// - [detailedPIDs] (`List<DetailedPID>`): List of PIDs to poll cyclically.
  /// - [onData] (`Function`): Callback triggered when new data arrives.
  /// - [pollIntervalMs] (`int`): Time in milliseconds between requests (default 300).
  /// - [adapter] (`AdapterOBD2`): The connected OBD-II adapter.
  /// - [noWarning] (`bool`): If true, suppresses console warnings about inefficient polling intervals (default false).
  ///
  /// ### Returns:
  /// - (`TelemetrySession`): The active session handle.
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is not connected.
  TelemetrySession stream({
    required List<DetailedPID> detailedPIDs,
    required void Function(TelemetryData) onData,
    int pollIntervalMs = 300,
    required AdapterOBD2 adapter,
    bool noWarning = false,
  });

  /// Performs a one-time telemetry snapshot query.
  ///
  /// ### Returns:
  /// - (`Future<Map<DetailedPID, dynamic>>`): Map of PID to its value (double, String, or List).
  Future<Map<DetailedPID, dynamic>> query({
    required List<DetailedPID> detailedPIDs,
    required AdapterOBD2 adapter,
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

/// A type-safe container for telemetry data.
///
/// Instead of a raw Map, this class uses generics to ensure that
/// retrieving a value matches the type defined in the PID.
class TelemetryData {
  /// The internal storage of values.
  final Map<DetailedPID, dynamic> _values;

  /// The timestamp of this data snapshot.
  final DateTime timestamp;

  TelemetryData(this._values, {DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  /// Retrieves a type-safe value for the given PID.
  ///
  /// This method uses the generic type [T] from the [pid] to ensure
  /// the return type matches the PID's definition.
  ///
  /// ### Parameters:
  /// - [detailedPID] (`DetailedPID<T>`): The PID to retrieve.
  ///
  /// ### Returns:
  /// - (T?): The value cast to type [T], or null if not present.
  ///
  /// ### Usage:
  /// ```dart
  /// double? rpm = data.get(rpmPID); // OK
  /// double? fuel = data.get(fuelStringPID); // COMPILE ERROR
  /// ```
  T? get<T>(DetailedPID<T> detailedPID) {
    return _values[detailedPID] as T?;
  }

  /// Helper to check if data exists.
  bool hasData(DetailedPID pid) => _values.containsKey(pid);
}