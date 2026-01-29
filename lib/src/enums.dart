/// Defines the type of data a PID returns.
///
/// This allows the [AdapterOBD2] to decide how to parse the raw bytes.
enum OBD2QueryReturnValue {
  /// A single floating point number (e.g., RPM, Speed, Temp).
  /// Parsed using the standard mathematical formula.
  double,

  /// A text string (e.g., VIN, Fuel Type Description).
  text,

  /// A status object or bitmask (e.g., Monitor Status 0101).
  /// usually returns a `Map<String, bool>` or a custom Object.
  status,

  /// A complex object containing multiple values.
  /// Used for PIDs like 0124 (Lambda + Voltage).
  composite,
}