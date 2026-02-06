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

  /// Starts a smart, priority-based telemetry streaming session.
  ///
  /// This stream automatically manages scheduling based on the [bestPollingIntervalMs]
  /// defined inside each [DetailedPID].
  ///
  /// - **High Priority PIDs** (e.g., RPM) will be queried frequently.
  /// - **Low Priority PIDs** (e.g., Fuel Level) will be skipped until their
  ///   interval has elapsed.
  ///
  /// ### Parameters:
  /// - [detailedPIDs]: The list of sensors to monitor.
  /// - [onData]: Callback triggered when new data arrives.
  /// - [adapter]: The connected OBD-II adapter.
  /// - [pollIntervalMs]: The **Bus Cool-down** time. The stream waits this long
  ///   *after* a query finishes before starting the next one.
  ///   Recommended: 10ms - 50ms.
  ///
  /// ### Returns:
  /// - (`TelemetrySession`): Control object to stop the stream.
  TelemetrySession stream({
    required List<DetailedPID> detailedPIDs,
    required void Function(TelemetryData) onData,
    required AdapterOBD2 adapter,
    int pollIntervalMs = 10,
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
/// - Recursive ECU polling
/// - Safe cancellation
class TelemetrySession {
  /// The callback function executed when [stop] is called.
  /// This is used to flip the internal `isRunning` flag in the loop.
  final void Function() _onStop;

  /// Creates a telemetry session with a cancellation callback.
  TelemetrySession(this._onStop);

  /// Stops the telemetry session and releases resources.
  void stop() {
    _onStop();
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