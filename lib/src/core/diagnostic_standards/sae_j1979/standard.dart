import '../standard_abstract.dart';
import '../../../models.dart';

import 'parameter_ids.dart' as pids;

/// SAE J1979 diagnostic standard implementation.
class SaeJ1979Standard implements DiagnosticStandard {
  @override
  String get name => 'SAE J1979';

  @override
  List<String> get initializationCommands => const [
    'AT Z',
    'AT E0',
    'AT L0',
    'AT SP 0',
  ];

  @override
  List<PIDInformation> get supportedParameterIDS => const [
    pids.rpm,
    // later: speed, coolant, throttle, etc.
  ];

  @override
  String buildParameterIDRequest(PIDInformation pIDInfo) {
    return pIDInfo.parameterID;
  }

  @override
  List<String> extractDataBytes({
    required String response,
    required PIDInformation pIDInfo,
  }) {
    final String header =
        '41${pIDInfo.parameterID.substring(pIDInfo.parameterID.length - 2)}';

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
