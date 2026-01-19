import 'package:obd2/obd2.dart';

/// SAE J1979 diagnostic standard implementation.
class SaeJ1979 extends DiagnosticStandard {

  static final DetailedPIDs _detailedPIDCatalog = DetailedPIDs();

  /// Namespace for SAE J1979 Parameter Identifiers.
  ///
  /// These PIDs are **static** and **standard-scoped**, meaning:
  /// - They belong to SAE J1979
  /// - They are not instance-bound
  /// - They do not pollute the global namespace
  DetailedPIDs get detailedPIDs => _detailedPIDCatalog;

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
  List<DetailedPID> get allowedDetailedPIDs => [
    detailedPIDs.rpm
    // later: speed, coolant, throttle, etc.
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
