import '../adapter_series/adapter_obd2.dart';

/// SAE J1979 Mode 03 – Stored Diagnostic Trouble Code (DTC) reader.
///
/// This class implements the official OBD-II Service Mode 03,
/// which retrieves confirmed (stored) Diagnostic Trouble Codes
/// from the vehicle’s Engine Control Unit (ECU).
///
/// Mode 03:
/// - Requires NO Parameter ID
/// - Returns all confirmed DTCs in one response
/// - Is the standard method used by consumer OBD scanners
///
/// This implementation:
/// - Uses service-level execution (not PID abstraction)
/// - Validates response structure
/// - Decodes DTC bit fields according to SAE J1979
/// - Does NOT swallow transport-level errors
///
/// ### Example Raw ECU Response:
///
/// ```
/// 43 01 33 02 10 00 00
/// ```
///
/// Where:
/// - 43 → Response to Mode 03 (0x03 + 0x40)
/// - 01 33 → First DTC
/// - 02 10 → Second DTC
/// - 00 00 → Padding
///
/// This class converts those bytes into:
///
/// ```
/// ["P0133", "P0210"]
/// ```
///
/// ### Throws:
/// - (`StateError`): If adapter is not connected.
/// - (Transport exceptions): Propagated from adapter layer.
///
class ReadCodes {

  /// Low-level OBD-II adapter used for ECU communication.
  final AdapterOBD2 _adapter;

  /// Creates a Mode 03 read codes controller.
  ///
  /// ### Parameters:
  /// - (`AdapterOBD2`): Active adapter instance.
  ReadCodes(this._adapter);

  /// Retrieves stored (confirmed) Diagnostic Trouble Codes.
  ///
  /// This method:
  /// 1. Verifies adapter connectivity
  /// 2. Sends Service Mode 03
  /// 3. Validates response format
  /// 4. Decodes returned DTC bytes
  ///
  /// Mode 03 returns:
  /// - All confirmed codes
  /// - In 2-byte packed format
  ///
  /// ### Returns:
  /// - (`Future<List<String>>`):
  ///   List of formatted DTC strings (e.g., ["P0300", "U0100"]).
  ///   Returns an empty list if no codes are stored.
  ///
  /// ### Usage:
  /// ```dart
  /// final storedCodes = await readCodes.getDTCs();
  /// ```
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is not connected.
  ///
  Future<List<String>> getDTCs() async {

    if (!_adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    // Send Mode 03 (Stored DTCs)
    final List<int>? payloadBytes = await _adapter.sendService("03");

    // If no payload or ECU returns NO DATA
    if (payloadBytes == null || payloadBytes.isEmpty) {
      return <String>[];
    }

    return _decodeDiagnosticTroubleCodes(payloadBytes);
  }

  /// Decodes raw Mode 03 payload bytes into formatted DTC strings.
  ///
  /// The adapter already strips the response header (0x43),
  /// so payloadBytes contains only:
  ///
  /// ```
  /// 01 33 02 10 00 00
  /// ```
  ///
  /// Each DTC occupies exactly 2 bytes.
  ///
  /// ### Parameters:
  /// - (`List<int>`): payloadBytes – Raw DTC bytes (header already removed).
  ///
  /// ### Returns:
  /// - (`List<String>`): Formatted DTC strings.
  ///
  List<String> _decodeDiagnosticTroubleCodes(List<int> payloadBytes) {
    final List<String> decodedCodes = <String>[];

    /*
      Each Diagnostic Trouble Code consists of:

      Byte A:
        Bits 7–6 → System prefix (P, C, B, U)
        Bits 5–4 → First numeric digit
        Bits 3–0 → Second numeric digit

      Byte B:
        Full 8 bits → Last two digits

      Structure:
        AAAAAAAA BBBBBBBB
    */

    for (int index = 0; index < payloadBytes.length; index += 2) {

      // Ensure we have a complete 2-byte pair.
      if (index + 1 >= payloadBytes.length) break;

      final int firstByte = payloadBytes[index];
      final int secondByte = payloadBytes[index + 1];

      // 0x00 0x00 indicates padding (no additional codes).
      if (firstByte == 0x00 && secondByte == 0x00) continue;

      final String formattedCode = _formatSingleDiagnosticTroubleCode(
        firstByte,
        secondByte,
      );

      decodedCodes.add(formattedCode);
    }

    return decodedCodes;
  }

  /// Converts a 2-byte packed DTC into SAE-standard format.
  ///
  /// Example:
  /// ```
  /// 0x01 0x33 → P0133
  /// ```
  ///
  /// ### Bit Mapping:
  ///
  /// - Bits 7–6 (firstByte) → System:
  ///     00 → P (Powertrain)
  ///     01 → C (Chassis)
  ///     10 → B (Body)
  ///     11 → U (Network)
  ///
  /// - Bits 5–4 → First numeric digit
  /// - Bits 3–0 → Second numeric digit
  /// - secondByte → Final two digits
  ///
  /// ### Parameters:
  /// - (`int`) firstByte: High-order byte of DTC.
  /// - (`int`) secondByte: Low-order byte of DTC.
  ///
  /// ### Returns:
  /// - (`String`): Formatted DTC string.
  ///
  String _formatSingleDiagnosticTroubleCode(
      int firstByte,
      int secondByte,
      ) {

    // Extract system bits (bits 7–6).
    final int systemBits = (firstByte & 0xC0) >> 6;

    String systemPrefix;

    switch (systemBits) {
      case 0:
        systemPrefix = "P"; // Powertrain
        break;
      case 1:
        systemPrefix = "C"; // Chassis
        break;
      case 2:
        systemPrefix = "B"; // Body
        break;
      case 3:
        systemPrefix = "U"; // Network
        break;
      default:
        systemPrefix = "P";
    }

    // Bits 5–4 determine the first numeric digit.
    final int firstDigit = (firstByte & 0x30) >> 4;

    // Lower 4 bits (bits 3–0) represent the second digit.
    final String secondDigit =
    (firstByte & 0x0F).toRadixString(16).toUpperCase();

    // Entire second byte becomes last two digits.
    final String lastTwoDigits =
    secondByte.toRadixString(16).toUpperCase().padLeft(2, '0');

    return "$systemPrefix$firstDigit$secondDigit$lastTwoDigits";
  }
}