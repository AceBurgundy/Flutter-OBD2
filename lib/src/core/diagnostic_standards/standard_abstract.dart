import '../../models.dart';

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
  List<PIDInformation> get supportedParameterIDS;

  /// Builds a request command for a given PID.
  String buildParameterIDRequest(PIDInformation pIDInfo);

  /// Extracts raw data bytes from an ECU response.
  List<String> extractDataBytes({
    required String response,
    required PIDInformation pIDInfo,
  });
}
