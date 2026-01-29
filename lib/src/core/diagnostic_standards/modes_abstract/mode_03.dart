import 'package:obd2/src/core/adapter_obd2.dart';

/// Abstract base class for Reading Diagnostic Trouble Codes (Mode 03).
///
/// Enables requesting the list of confirmed emission-related DTCs.
abstract class ReadCodesMode {
  ReadCodesMode();

  /// OBD-II service mode identifier.
  static const String mode = '03';

  /// Fetches the list of stored diagnostic trouble codes.
  ///
  /// ### Parameters:
  /// - [adapter]: The connected OBD-II adapter.
  ///
  /// ### Returns:
  /// - (`Future<List<String>>`): A list of codes (e.g. ["P0300", "P0101"]).
  Future<List<String>> getDiagnosticTroubleCodes(AdapterOBD2 adapter);
}