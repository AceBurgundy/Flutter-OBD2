/// Holds constant identifiers for supported OBD-II diagnostic standards.
///
/// This class acts as a registry for the string IDs used to map
/// `DiagnosticStandard` implementations to their respective protocol logic.
class DiagnosticStandardIDs {

  /// Identifier for the SAE J1979 standard (Generic OBD-II).
  ///
  /// This is the most common standard used for emission-related diagnostics
  /// in passenger vehicles.
  static const String saeJ1979 = "sae_j1979";
}