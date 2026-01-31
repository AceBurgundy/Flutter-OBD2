import 'package:obd2/obd2.dart';

/// A structured representation of a single OBD-II Parameter ID (PID).
///
/// The generic type [T] defines the data type returned by this PID.
/// - `DetailedPID<double>`: Returns a double (e.g. RPM).
/// - `DetailedPID<String>`: Returns a String (e.g. VIN).
/// - `DetailedPID<List<double>>`: Returns a list (e.g. Lambda).
class DetailedPID<T> {
  final String standard;
  final String parameterID;
  final String name;
  final String formula;
  final OBD2QueryReturnValue obd2QueryReturnType;

  /// The suggested polling interval in milliseconds.
  ///
  /// This integer represents the ideal delay between requests for this specific PID
  /// to balance bus load and data freshness.
  ///
  /// - **Low Value (e.g., 20)**: High priority (RPM, Speed).
  /// - **High Value (e.g., 10000)**: Low priority (Odometer, Fuel Level).
  /// - **Null**: Use the session's default interval.
  final int bestPollingIntervalMs;

  const DetailedPID(
    this.standard,
    this.parameterID,
    this.name,
    this.formula, {
    this.obd2QueryReturnType = OBD2QueryReturnValue.double,
    this.bestPollingIntervalMs = 250,
  });

  @override
  String toString() => "$name ($parameterID)";
}