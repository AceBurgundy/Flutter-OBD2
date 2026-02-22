import '../../../obd2.dart';
import '../adapter_series/adapter_obd2.dart';
import '../standard_ids.dart';

/// SAE J1979 Implementation of Read Codes Mode.
class ReadCodes {

  final AdapterOBD2 _adapter;

  /// Creates a SAE J1979 read codes controller.
  ///
  /// ### Parameters:
  /// - (AdapterOBD2): Active adapter instance.
  ReadCodes(this._adapter);

  /// The standard command to request stored codes.
  static const String _commandReadStored = "03";

  /// Retrieves the list of Diagnostic Trouble Codes (DTCs) from the vehicle.
  ///
  /// This method checks the adapter connection, sends the standard Mode 03 request,
  /// and interprets the raw byte response into human-readable DTC strings.
  ///
  /// ### Returns:
  /// - (`Future<List<String>>`): A list of formatted DTC strings (e.g., "P0300"). Returns an empty list if no codes are found or if an error occurs.
  ///
  /// ### Usage:
  /// ```dart
  /// final codes = await mode03.getDTCs();
  /// print(codes); // ['P0100', 'P0200']
  /// ```
  Future<List<String>> getDTCs() async {
    if (!_adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    try {
      // We create a temporary "dummy" PID to utilize the existing query infrastructure
      // or we can manually send the command if the adapter exposes a raw send method.
      // Assuming we can send a custom PID request:
      final DetailedPID requestDetailedPID = const DetailedPID(
        DiagnosticStandardIDs.saeJ1979,
        _commandReadStored,
        'Read Stored DTCs',
        '', // No formula, custom parsing
        obd2QueryReturnType: QueryReturnValue.status, // Return raw bytes
      );

      // This query returns List<int> (raw bytes) because of .status type
      final dynamic rawResponse = await _adapter.queryPID(requestDetailedPID);

      if (rawResponse is List<int>) {
        return _decodeDTCs(rawResponse);
      }

      return [];
    } catch (error) {
      // If reading DTCs fails, return an empty list to indicate no codes found
      return [];
    }
  }

  /// Decodes raw bytes into a list of DTC strings.
  ///
  /// ### Parameters:
  /// - (`List<int>`): responseBytes - Raw data bytes received from the ECU.
  ///
  /// ### Returns:
  /// - (`List<String>`): A list of formatted DTC codes.
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
    } catch (error) {
      // If decoding fails partway, return what we have so far
      return codes;
    }

    return codes;
  }

  /// Converts 2 raw bytes into standard OBD-II format (e.g. P0300).
  ///
  /// ### Parameters:
  /// - (`int`): byteA - The first byte of the 2-byte DTC.
  /// - (`int`): byteB - The second byte of the 2-byte DTC.
  ///
  /// ### Returns:
  /// - (`String`): The fully formatted DTC string (e.g., "P0300", "U1000").
  String _parseSingleDTC(int byteA, int byteB) {
    try {
      // 1. Determine Prefix (Bits 7-6 of Byte A)
      final int typeBits = (byteA & 0xC0) >> 6;
      String prefix;

      switch (typeBits) {
        case 0:
          prefix = "P";
          break; // Powertrain

        case 1:
          prefix = "C";
          break; // Chassis

        case 2:
          prefix = "B";
          break; // Body

        case 3:
          prefix = "U";
          break; // Network

        default:
          prefix = "P";
      }

      // 2. Determine Second Digit (Bits 5-4 of Byte A)
      final int secondDigit = (byteA & 0x30) >> 4;

      // 3. Third Digit (Lower 4 bits of Byte A)
      final String thirdDigit = (byteA & 0x0F).toRadixString(16).toUpperCase();

      // 4. Last Two Digits (Byte B)
      final String lastTwoDigits =
      byteB.toRadixString(16).toUpperCase().padLeft(2, '0');

      return "$prefix$secondDigit$thirdDigit$lastTwoDigits";
    } catch (error) {
      return "UNKNOWN";
    }
  }
}