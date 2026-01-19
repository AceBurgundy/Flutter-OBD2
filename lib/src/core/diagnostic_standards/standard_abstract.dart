import '../../../obd2.dart';

/// Defines the contract for an OBD-II diagnostic standard.
///
/// A diagnostic standard is responsible for:
/// - Exposing supported PIDs
/// - Providing adapter initialization commands
/// - Building PID requests
/// - Parsing ECU responses
abstract class DiagnosticStandard {
  /// Human-readable name of the diagnostic standard.
  String get name;

  /// List of AT commands required to initialize the adapter.
  List<String> get initializationCommands;

  /// All supported parameter identifiers for this standard.
  List<DetailedPID> get allowedDetailedPIDs;

  /// Builds a request command for a given PID.
  String buildDetailedPIDRequest(DetailedPID detailedPID);

  /// Extracts raw data bytes from an ECU response.
  List<String> extractDataBytes({
    required String response,
    required DetailedPID detailedPID,
  });
}
