import 'package:obd2/src/core/adapter_obd2.dart';

/// Abstract base class for Clearing Diagnostic Trouble Codes (Mode 04).
///
/// Enables clearing stored DTCs and resetting the Check Engine Light (MIL).
abstract class ClearCodesMode {
  ClearCodesMode();

  /// OBD-II service mode identifier.
  static const String mode = '04';

  /// Clears the stored diagnostic trouble codes.
  ///
  /// **Warning:** This will also reset inspection readiness monitors.
  ///
  /// ### Parameters:
  /// - [adapter]: The connected OBD-II adapter.
  ///
  /// ### Returns:
  /// - (`Future<bool>`): True if the clear command was acknowledged successfully.
  Future<bool> clearDiagnosticTroubleCodes(AdapterOBD2 adapter);
}