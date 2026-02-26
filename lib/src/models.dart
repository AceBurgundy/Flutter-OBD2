import 'package:obd2/obd2.dart';

/// Immutable result of an odometer update operation.
///
/// Contains:
/// - Updated odometer value
/// - Exact timestamp used for calculation
class OdometerUpdateResult {

  /// Updated odometer reading in kilometers.
  final double updatedOdometer;

  /// Timestamp captured internally during calculation.
  final DateTime timestamp;

  const OdometerUpdateResult({
    required this.updatedOdometer,
    required this.timestamp,
  });
}


/// Strongly typed telemetry snapshot container.
///
/// This class ensures type safety when retrieving values.
class TelemetryData {

  /// Internal storage of PID values.
  final Map<DetailedPID, dynamic> _values;

  /// Timestamp of this telemetry snapshot.
  final DateTime timestamp;

  /// Creates a telemetry data snapshot.
  ///
  /// If no timestamp is provided, the current time is used.
  TelemetryData(this._values, {DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();

  /// Retrieves a strongly typed value.
  ///
  /// ### Parameters:
  /// - [detailedPID]: PID definition.
  ///
  /// ### Returns:
  /// - Typed value or null.
  T? get<T>(DetailedPID<T> detailedPID) {
    return _values[detailedPID] as T?;
  }

  /// Returns true if data exists for a PID.
  bool hasData(DetailedPID detailedPID) => _values.containsKey(detailedPID);
}

/// A structured representation of a single OBD-II Parameter ID (PID).
///
/// The generic type [T] defines the data type returned by this PID.
///
/// - `DetailedPID<double>`: Numeric sensor values (RPM, temperature).
/// - `DetailedPID<String>`: Text values (Fuel Type).
/// - `DetailedPID<List<double>>`: Composite responses (Lambda & Voltage).
class DetailedPID<T> {
  /// The diagnostic standard this PID belongs to.
  final String standard;

  /// The hexadecimal Mode + PID string (e.g., `010C`).
  final String parameterID;

  /// Human-readable name of the PID.
  final String name;

  /// Formula used to decode raw ECU bytes into a value.
  ///
  /// Uses indexed byte notation:
  /// - `[0]` = first byte
  /// - `[1]` = second byte
  final String formula;

  /// Engineering unit (e.g., `rpm`, `celsius`, `kPa`, `percent`).
  final String unit;

  /// Defines how the adapter should interpret the ECU response.
  final QueryReturnValue obd2QueryReturnType;

  /// Suggested polling interval in milliseconds.
  final int pollingIntervalMs;

  const DetailedPID(
      this.standard,
      this.parameterID,
      this.name,
      this.formula, {
        this.unit = '',
        this.obd2QueryReturnType = QueryReturnValue.double,
        this.pollingIntervalMs = 250,
      });

  @override
  String toString() => "$name ($parameterID)";
}