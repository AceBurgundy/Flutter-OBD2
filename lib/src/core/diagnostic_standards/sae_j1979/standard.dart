import 'package:obd2/obd2.dart';

import '../../standard_ids.dart';

/// SAE J1979 diagnostic standard implementation.
class SaeJ1979 extends DiagnosticStandard {

  @override
  String get name => 'SAE J1979';

  @override
  String get id => DiagnosticStandardIDs.saeJ1979;

  SAEJ1979ModeTelemetry telemetry = SAEJ1979ModeTelemetry();

  @override
  List<String> get initializationCommands => const [
    'AT Z',
    'AT E0',
    'AT L0',
    'AT SP 0',
  ];

  @override
  String buildDetailedPIDRequest(DetailedPID detailedPID) {
    return detailedPID.parameterID;
  }

  @override
  List<String> extractDataBytes({
    required String response,
    required DetailedPID detailedPID,
  }) {
    final String header = '41${detailedPID.parameterID.substring(detailedPID.parameterID.length - 2)}';

    String cleaned = response;
    if (cleaned.contains(header) == true) {
      cleaned = cleaned.split(header).last;
    }

    final List<String> bytes = [];
    for (int index = 0; index < cleaned.length; index += 2) {
      if (index + 2 <= cleaned.length) {
        bytes.add(cleaned.substring(index, index + 2));
      }
    }

    return bytes;
  }
}
