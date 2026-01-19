
import '../../../../obd2.dart';

/// DetailedPIDCatalog = Namespace for all PIDInformation of a standard.
///
/// Contains telemetry definitions (ID, description, formula) scoped to the standard.
/// This class is internal to the standard and not exported outside the package.
class DetailedPIDs {

  /// Engine Revolutions Per Minute.
  final DetailedPID rpm = const DetailedPID(
    '010C',
    'Engine Revolutions Per Minute',
    '([0] * 256 + [1]) / 4',
  );

  /// Engine Coolant Temperature.
  final DetailedPID coolantTemperature = const DetailedPID(
    '0105',
    'Engine Coolant Temperature',
    '[0] - 40',
  );
}
