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

  const DetailedPID(
      this.standard,
      this.parameterID,
      this.name,
      this.formula, {
        this.obd2QueryReturnType = OBD2QueryReturnValue.double,
      });

  @override
  String toString() => "$name ($parameterID)";
}