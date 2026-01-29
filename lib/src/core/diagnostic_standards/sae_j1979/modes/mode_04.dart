
import 'package:obd2/obd2.dart';
import 'package:obd2/src/core/adapter_obd2.dart';
import 'package:obd2/src/core/diagnostic_standards/modes_abstract/mode_04.dart';
import 'package:obd2/src/core/standard_ids.dart';

/// SAE J1979 Implementation of Clear Codes Mode.
class SAEJ1979ClearCodesMode extends ClearCodesMode {
  SAEJ1979ClearCodesMode();

  /// The command string to clear DTCs.
  static const String _commandClearDTCs = "04";

  @override
  Future<bool> clearDiagnosticTroubleCodes(AdapterOBD2 adapter) async {
    if (!adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    try {
      // Create a dummy PID to send the "04" command.
      // We expect a text response usually (like "OK" or "44") or raw bytes.
      final DetailedPID<String> clearDetailedPID = const DetailedPID(
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

    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to clear diagnostic trouble codes.',
      );
      return false;
    }
  }
}