/// Collection of unit conversion helpers used by telemetry values.
///
/// This file is intentionally placed outside `core` so it can be reused
/// by UI layers, analytics, exports, and integrations without pulling
/// in Bluetooth or OBD logic.
class UnitConversions {

  /// Converts revolutions per minute to revolutions per second.
  static double rpmToRps(double rpm) => rpm / 60.0;

  /// Converts revolutions per second to revolutions per minute.
  static double rpsToRpm(double rps) => rps * 60.0;
}
