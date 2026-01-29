
import 'package:obd2/src/core/diagnostic_standards/modes_abstract/mode_03.dart';
import 'package:obd2/src/core/standard_ids.dart';
import 'package:obd2/src/core/adapter_obd2.dart';
import 'package:obd2/obd2.dart';

/// SAE J1979 Implementation of Read Codes Mode.
class SAEJ1979ReadCodesMode extends ReadCodesMode {
  SAEJ1979ReadCodesMode();

  /// The standard command to request stored codes.
  static const String _commandReadStored = "03";

  @override
  Future<List<String>> getDiagnosticTroubleCodes(AdapterOBD2 adapter) async {
    if (!adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    try {
      // We create a temporary "dummy" PID to utilize the existing query infrastructure
      // or we can manually send the command if the adapter exposes a raw send method.
      // Assuming we can send a custom PID request:
      final DetailedPID<List<int>> requestDetailedPID = const DetailedPID(
        DiagnosticStandardIDs.saeJ1979,
        _commandReadStored,
        'Read Stored DTCs',
        '', // No formula, custom parsing
        obd2QueryReturnType: OBD2QueryReturnValue.status, // Return raw bytes
      );

      // This query returns List<int> (raw bytes) because of .status type
      final dynamic rawResponse = await adapter.queryPID(requestDetailedPID);

      if (rawResponse is List<int>) {
        return _decodeDTCs(rawResponse);
      }
      
      return [];

    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to read diagnostic trouble codes.',
      );
      return [];
    }
  }

  /// Decodes raw bytes into a list of DTC strings.
  ///
  /// ### Parameters:
  /// - [responseBytes] (`List<int>`): Raw data from ECU.
  ///
  /// ### Returns:
  /// - (`List<String>`): Formatted codes.
  List<String> _decodeDTCs(List<int> responseBytes) {
    final List<String> codes = [];
    try {
      // Iterate in steps of 2 (each code is 2 bytes)
      for (int index = 0; index < responseBytes.length; index += 2) {
        if (index + 1 >= responseBytes.length) break;

        final int byteA = responseBytes[index];
        final int byteB = responseBytes[index + 1];

        // 0x00 0x00 is padding
        if (byteA == 0 && byteB == 0) continue;

        codes.add(_parseSingleDTC(byteA, byteB));
      }
    } catch (error, stackTrace) {
      logError(error, stackTrace, message: "Error decoding DTC list bytes");
    }
    return codes;
  }

  /// Converts 2 raw bytes into standard OBD-II format (e.g. P0300).
  String _parseSingleDTC(int byteA, int byteB) {
    try {
      // 1. Determine Prefix (Bits 7-6 of Byte A)
      final int typeBits = (byteA & 0xC0) >> 6;
      String prefix;

      switch (typeBits) {
        case 0: prefix = "P"; break; // Powertrain
        case 1: prefix = "C"; break; // Chassis
        case 2: prefix = "B"; break; // Body
        case 3: prefix = "U"; break; // Network
        default: prefix = "P";
      }

      // 2. Determine Second Digit (Bits 5-4 of Byte A)
      final int secondDigit = (byteA & 0x30) >> 4;

      // 3. Third Digit (Lower 4 bits of Byte A)
      final String thirdDigit = (byteA & 0x0F).toRadixString(16).toUpperCase();

      // 4. Last Two Digits (Byte B)
      final String lastTwoDigits = byteB.toRadixString(16).toUpperCase().padLeft(2, '0');

      return "$prefix$secondDigit$thirdDigit$lastTwoDigits";
    } catch (error, stackTrace) {
      logError(error, stackTrace, message: "Error parsing single DTC: $byteA, $byteB");
      return "UNKNOWN";
    }
  }
}
