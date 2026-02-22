import '../../../obd2.dart';
import '../adapter_series/adapter_obd2.dart';
import '../standard_ids.dart';

/// SAE J1979 Implementation of Clear Codes Mode.
class ClearCodes {

  final AdapterOBD2 _adapter;

  /// Creates a SAE J1979 clear codes controller.
  ///
  /// ### Parameters:
  /// - (AdapterOBD2): Active adapter instance.
  ClearCodes(this._adapter);

  /// The command string to clear DTCs.
  static const String _commandClearDTCs = "04";

  /// Clears the Diagnostic Trouble Codes (DTCs) and resets the "Check Engine" light.
  ///
  /// This method sends the standard Mode 04 command to the vehicle's ECU.
  /// This action typically erases stored trouble codes and freeze frame data.
  ///
  /// ### Returns:
  /// - (`Future<bool>`): Returns `true` if the ECU responds positively (e.g., "44" or "OK"), otherwise `false`.
  ///
  /// ### Usage:
  /// ```dart
  /// final success = await mode04.clearDiagnosticTroubleCodes();
  /// if (success) {
  ///   print('Codes cleared successfully.');
  /// }
  /// ```
  Future<bool> clearDiagnosticTroubleCodes() async {
    if (!_adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    try {
      // Create a dummy PID to send the "04" command.
      // We expect a text response usually (like "OK" or "44") or raw bytes.
      final DetailedPID clearDetailedPID = const DetailedPID(
        DiagnosticStandardIDs.saeJ1979,
        _commandClearDTCs,
        'Clear DTCs',
        '',
        obd2QueryReturnType: QueryReturnValue.text,
      );

      // Sending "04"
      // Note: The adapter might interpret "04" as a PID if using buildDetailedPIDRequest.
      // Ideally, the adapter should have a raw sendCommand method, but we reuse queryPID here.
      final dynamic response = await _adapter.queryPID(clearDetailedPID);

      // Check success
      // ELM327 positive response to "04" is usually "44"
      if (response is String) {
        return response.contains("44") || response.contains("OK");
      }

      return false;
    } catch (error) {
      return false;
    }
  }
}