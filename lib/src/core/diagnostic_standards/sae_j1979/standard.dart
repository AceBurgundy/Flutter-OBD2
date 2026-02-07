import 'package:obd2/obd2.dart';
import '../../standard_ids.dart';

/// SAE = Society of Automotive Engineers
/// J1979 = The specific standard for OBD-II diagnostics.
///
/// SAE J1979 diagnostic standard implementation.
///
/// This class handles the formatting of commands and the parsing of responses
/// according to the SAE J1979 protocol.
class SaeJ1979 extends DiagnosticStandard {

  @override
  String get name => 'SAE J1979';

  @override
  String get id => DiagnosticStandardIDs.saeJ1979;

  SAEJ1979ModeTelemetry telemetry = SAEJ1979ModeTelemetry();

  @override
  List<String> get initializationCommands => const [
    'AT Z',   // Reset
    'AT E0',  // Echo Off
    'AT L0',  // Linefeeds Off
    'AT SP 0',// Auto Protocol
  ];

  @override
  String buildDetailedPIDRequest(DetailedPID detailedPID) {
    return detailedPID.parameterID;
  }

  /// Extracts raw data bytes from a raw ELM327 response string.
  ///
  /// This method cleans the response (removes headers, spaces, errors) and
  /// isolates the specific hex bytes relevant to the requested PID.
  ///
  /// ### Parameters:
  /// - [response] (String): The raw ASCII response from the adapter.
  /// - [detailedPID] (DetailedPID): The PID that was requested.
  ///
  /// ### Returns:
  /// - (List<String>): A list of hex strings (e.g. `['1A', 'F8']`). Returns empty if parsing fails.
  @override
  List<String> extractDataBytes({
    required String response,
    required DetailedPID detailedPID,
  }) {
    try {
      // 1. Clean the response
      // We remove spaces, newlines, carriage returns, the prompt '>', and specific ELM status messages.
      String cleaned = response
          .replaceAll(RegExp(r'\s+'), '') // Remove all whitespace
          .replaceAll('>', '')
          .replaceAll('SEARCHING...', '')
          .replaceAll('STOPPED', '')
          .toUpperCase();

      // 2. Determine Expected Header
      // For PID "010C", the expected response header is "410C".
      // We strip the mode (first 2 chars) from the PID to get the ID.
      final String pidId = detailedPID.parameterID.substring(2);
      final String expectedHeader = '41$pidId';

      // 3. Find the Frame
      // Real ELM327 responses might look like "7E8 04 41 0C 1A F8" (CAN) or "41 0C 1A F8" (K-Line).
      // We look for "410C" anywhere in the cleaned string.
      final int index = cleaned.indexOf(expectedHeader);

      if (index == -1) {
        return [];
      }

      // 4. Extract Payload
      // The data bytes start immediately after the header (4 chars).
      // "410C1AF8" -> payload is "1AF8"
      final String payload = cleaned.substring(index + 4);

      // 5. Convert to Hex List
      final List<String> bytes = [];
      for (int index = 0; index < payload.length; index += 2) {
        if (index + 2 <= payload.length) {
          bytes.add(payload.substring(index, index + 2));
        }
      }

      return bytes;
    } catch (error, stackTrace) {
      logError(error, stackTrace, message: 'SAE J1979 frame parsing failed for ${detailedPID.name}.');
      return [];
    }
  }
}