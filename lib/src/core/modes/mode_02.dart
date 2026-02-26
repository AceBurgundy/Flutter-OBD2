import '../../../obd2.dart';
import '../adapter_series/adapter_obd2.dart';
import '../standard_ids.dart';

/// SAE J1979 Implementation of Freeze Frame Mode.
///
/// This class handles the retrieval of vehicle snapshots taken when a 
/// diagnostic trouble code (DTC) is triggered.
class FreezeFrame {
  /// OBD: On-Board Diagnostics
  /// DTC: Diagnostic Trouble Code
  /// PID: Parameter Identification Data

  /// The static definition for the PID that identifies the DTC causing the freeze frame.
  /// 
  /// Marked as `List<int>` to match the raw bytes returned by the `status` query type.
  static final DetailedPID<List<int>> freezeFrameDTC = DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0202',
    'Diagnostic Trouble Code Causing Freeze Frame',
    '',
    obd2QueryReturnType: QueryReturnValue.status,
  );

  /// The active adapter instance used for vehicle communication.
  final AdapterOBD2 _adapter;

  /// Creates a SAE J1979 freeze frame controller.
  ///
  /// ### Parameters
  /// - [_adapter] (`AdapterOBD2`): The active adapter instance used to send queries.
  FreezeFrame(this._adapter);

  /// Retrieves the stored freeze frame data from the vehicle.
  ///
  /// This method identifies the [DTC] that triggered the freeze frame using 
  /// [freezeFrameDTC] and then iterates through Mode 01 PIDs to capture 
  /// the sensor values at the moment the fault occurred.
  ///
  /// ### Returns
  /// - (`Future<Map<DetailedPID, dynamic>>`): A map containing the PIDs and 
  /// their respective values.
  ///
  /// ### Throws
  /// * [StateError]: if the adapter is not currently connected to a vehicle.
  ///
  /// ### Usage
  /// ```dart
  /// final frameData = await freezeFrame.getFrameData();
  /// ```
  Future<Map<DetailedPID, dynamic>> getFrameData() async {
    if (!_adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    final Map<DetailedPID, dynamic> results = {};

    // ---- Step 1: Query Freeze Frame DTC (0202) ----
    final List<int>? dtcBytes = await _adapter.queryPID(freezeFrameDTC);

    if (dtcBytes == null || dtcBytes.length < 2) {
      return results; // No freeze frame stored
    }

    final String decodedDTC = _decodeDTC(dtcBytes[0], dtcBytes[1]);

    // Add decoded DTC to results using the static PID key for consistency
    results[freezeFrameDTC] = decodedDTC;

    // ---- Step 2: Query all Mode 01 PIDs as Mode 02 ----
    for (final DetailedPID livePID in Telemetry.allDetailedPIDs) {
      // Guard: Only convert PIDs that are explicitly Mode 01
      if (!livePID.parameterID.startsWith('01')) continue;

      // Defensive Check: Skip 0102 to avoid a redundant 0202 query (already handled above)
      if (livePID.parameterID == '0102') continue;

      // Constructs a Mode 02 PID by replacing the first two characters with '02'
      final DetailedPID freezePID = DetailedPID(
        DiagnosticStandardIDs.saeJ1979,
        '02${livePID.parameterID.substring(2)}',
        livePID.name,
        livePID.formula,
        unit: livePID.unit,
        obd2QueryReturnType: livePID.obd2QueryReturnType,
      );

      try {
        final dynamic value = await _adapter.queryPID(freezePID);

        if (value != null) {
          // Mapping back to the original livePID key makes it easier for UI components 
          // to reuse existing formatting logic.
          results[livePID] = value;
        }
      } catch (_) {
        continue; // Skip PIDs that the vehicle does not support in Mode 02
      }
    }

    return results;
  }

  /// Decodes raw bytes into a standard OBD-II Diagnostic Trouble Code string.
  ///
  /// Maps the high bits of the first byte to the system categories (P, C, B, U)
  /// and converts the remaining nibbles into hexadecimal digits.
  ///
  /// 
  /// 
  /// ### Parameters
  /// - [byteA] (`int`): The first byte of the DTC data.
  /// - [byteB] (`int`): The second byte of the DTC data.
  ///
  /// ### Returns
  /// - (`String`): The 5-character formatted DTC (e.g., "P0300").
  ///
  /// ### Usage
  /// ```dart
  /// final code = _decodeDTC(0x43, 0x20); // Returns "C0320"
  /// ```
  String _decodeDTC(int byteA, int byteB) {
    // Determine the system prefix (Powertrain, Chassis, Body, Network)
    final int systemBits = (byteA & 0xC0) >> 6;
    final String system = ['P', 'C', 'B', 'U'][systemBits];

    final int digit1 = (byteA & 0x30) >> 4;
    final int digit2 = byteA & 0x0F;
    final int digit3 = (byteB & 0xF0) >> 4;
    final int digit4 = byteB & 0x0F;

    return '$system$digit1$digit2$digit3$digit4';
  }
}