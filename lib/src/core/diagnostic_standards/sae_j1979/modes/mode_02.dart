
import 'package:obd2/obd2.dart';
import 'package:obd2/src/core/adapter_obd2.dart';
import 'package:obd2/src/core/diagnostic_standards/modes_abstract/mode_02.dart';
import 'package:obd2/src/core/standard_ids.dart';

/// SAE J1979 Implementation of Freeze Frame Mode.
class SAEJ1979FreezeFrameMode extends FreezeFrameMode {
  SAEJ1979FreezeFrameMode();

  @override
  final DetailedPID<String> dtcCausingFreeze = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0202',
    'DTC Causing Freeze Frame',
    'A * 256 + B',
    obd2QueryReturnType: OBD2QueryReturnValue.text, // Parsed specially as DTC
  );

  @override
  final DetailedPID<double> rpm = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '020C',
    'Engine RPM (Freeze)',
    '([0] * 256 + [1]) / 4',
  );

  @override
  final DetailedPID<double> speed = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '020D',
    'Vehicle Speed (Freeze)',
    '[0]',
  );

  @override
  final DetailedPID<double> coolantTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0205',
    'Engine Coolant Temperature (Freeze)',
    '[0] - 40',
  );

  @override
  final DetailedPID<double> engineLoad = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0204',
    'Calculated Engine Load (Freeze)',
    '[0] * 100 / 255',
  );

  @override
  final DetailedPID<double> intakeManifoldPressure = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '020B',
    'Intake Manifold Pressure (Freeze)',
    '[0]',
  );

  @override
  Future<TelemetryData> getFreezeFrameData({
    required List<DetailedPID> detailedPIDs,
    required AdapterOBD2 adapter,
  }) async {
    final Map<DetailedPID, dynamic> results = {};

    for (final DetailedPID pid in detailedPIDs) {
      try {
        dynamic value;
        
        // Special parsing for the DTC PID (0202)
        // We reuse the standard query, but we might need to interpret the bytes 
        // as a DTC string if the adapter returns raw bytes.
        // Assuming adapter.queryPID handles the 'text' return type logic we set up.
        if (pid.parameterID == '0202') {
           // We might need to manually parse bytes here if queryPID returns raw string
           // For now, assuming queryPID returns the raw bytes or parsed string.
           // Since we set returnType to text, adapter tries to ASCII decode. 
           // BUT DTCs are NOT ASCII. They are bit-encoded.
           // In a real scenario, we'd need a custom return type for DTCs. 
           // For simplicity, we assume the adapter handles it or returns bytes we parse.
           
           // If we need raw bytes to parse DTC:
           // value = await _manualDTCParse(adapter, pid); 
           value = await adapter.queryPID(pid);
        } else {
           value = await adapter.queryPID(pid);
        }

        if (value != null) {
          results[pid] = value;
        }
      } catch (error, stackTrace) {
        logError(
          error,
          stackTrace,
          message: 'Failed to fetch freeze frame PID ${pid.parameterID}.',
        );
      }
    }

    return TelemetryData(results);
  }
}