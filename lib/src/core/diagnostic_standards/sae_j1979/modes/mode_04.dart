import 'package:obd2/obd2.dart';
import 'package:obd2/src/core/adapter_obd2.dart';
import 'package:obd2/src/core/diagnostic_standards/modes_abstract/mode_04.dart';
import 'package:obd2/src/core/standard_ids.dart';

/// SAE J1979 Implementation of Clear Codes Mode.
class SAEJ1979ClearCodesMode extends ClearCodesMode {

  /// Creates an instance of the SAE J1979 Clear Codes Mode.
  SAEJ1979ClearCodesMode();

  /// The command string to clear DTCs.
  static const String _commandClearDTCs = "04";

  /// Clears the Diagnostic Trouble Codes (DTCs) and resets the "Check Engine" light.
  ///
  /// This method sends the standard Mode 04 command to the vehicle's ECU.
  /// This action typically erases stored trouble codes and freeze frame data.
  ///
  /// ### Parameters:
  /// - (`AdapterOBD2`): adapter - The connected OBD2 adapter instance.
  ///
  /// ### Returns:
  /// - (`Future<bool>`): Returns `true` if the ECU responds positively (e.g., "44" or "OK"), otherwise `false`.
  ///
  /// ### Usage:
  /// ```dart
  /// final success = await mode04.clearDiagnosticTroubleCodes(adapter);
  /// if (success) {
  ///   print('Codes cleared successfully.');
  /// }
  /// ```
  ///
  /// ### Throws:
  /// - (`StateError`): If the adapter is not connected.
  @override
  Future<bool> clearDiagnosticTroubleCodes(AdapterOBD2 adapter) async {
    if (!adapter.isConnected) {
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
        obd2QueryReturnType: OBD2QueryReturnValue.text,
      );

      // Sending "04"
      // Note: The adapter might interpret "04" as a PID if using buildDetailedPIDRequest.
      // Ideally, the adapter should have a raw sendCommand method, but we reuse queryPID here.
      final dynamic response = await adapter.queryPID(clearDetailedPID);

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