import '../adapter_series/adapter_obd2.dart';

/// SAE J1979 Mode 04 – Clear Diagnostic Trouble Codes.
///
/// This class implements OBD-II Service Mode 04,
/// which clears stored Diagnostic Trouble Codes (DTCs)
/// and resets emission-related diagnostic data.
///
/// Mode 04:
/// - Clears confirmed DTCs (Mode 03)
/// - Clears pending DTCs (Mode 07)
/// - Clears freeze frame data (Mode 02)
/// - Resets readiness monitors
/// - Turns off the Malfunction Indicator Lamp (MIL)
///
/// This operation has regulatory implications:
/// - Emissions readiness becomes "NOT READY"
/// - Drive cycles are required before inspection
///
/// ### Example ECU Response:
///
/// ```
/// 44
/// ```
///
/// Where:
/// - 44 → Positive response (0x04 + 0x40)
///
/// ### Throws:
/// - (`StateError`): If adapter is not connected.
/// - (Transport exceptions): Propagated from adapter layer.
///
class ClearCodes {

  /// Low-level OBD-II adapter used for ECU communication.
  final AdapterOBD2 _adapter;

  /// Creates a Mode 04 clear codes controller.
  ///
  /// ### Parameters:
  /// - (`AdapterOBD2`): Active adapter instance.
  ClearCodes(this._adapter);

  /// Executes Mode 04 and clears diagnostic trouble codes.
  ///
  /// This method:
  /// 1. Verifies adapter connectivity
  /// 2. Sends Service Mode 04
  /// 3. Validates positive ECU acknowledgment
  ///
  /// If successful:
  /// - Stored DTCs are erased
  /// - Pending DTCs are erased
  /// - Freeze frame data is erased
  /// - MIL is turned off
  /// - Readiness monitors reset
  ///
  /// ### Returns:
  /// - (`Future<bool>`):
  ///   `true` if ECU acknowledges successful clearing.
  ///   `false` if ECU explicitly rejects or returns invalid response.
  ///
  /// ### Usage:
  /// ```dart
  /// final bool wasCleared = await clearCodes.clearStoredDiagnosticTroubleCodes();
  /// ```
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is not connected.
  ///
  Future<bool> eraseDTCs() async {

    if (!_adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    /*
      Mode 04 is a pure service-level command.

      sendService("04") performs:
      - Raw command execution
      - Response header validation (expects 0x44)
      - Header stripping
      - Returns payload bytes only

      For Mode 04:
      - A successful response typically has no payload
      - Some ECUs may return minimal status bytes
    */

    final List<int>? payloadBytes = await _adapter.sendService("04");

    // If adapter returns null, ECU likely responded with NO DATA.
    if (payloadBytes == null) {
      return false;
    }

    /*
      According to SAE J1979:

      Positive response to Mode 04:
        0x44

      Since Adapter strips the header (0x44),
      payloadBytes should normally be empty.

      Therefore:
      - Empty payload is considered successful.
      - Non-empty payload is tolerated but unusual.
    */

    return true;
  }
}