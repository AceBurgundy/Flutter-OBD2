import 'dart:async';

import 'package:obd2/src/functions.dart';
import '../../../../models.dart';
import '../../../adapter_obd2.dart';
import '../../../standard_ids.dart';
import '../../modes_abstract/mode_01.dart';

/// SAE = Society of Automotive Engineers
/// PID = Parameter Identifier
///
/// SAE J1979 Mode 01 telemetry implementation.
///
/// Provides access to standard live powertrain telemetry
/// defined by the SAE J1979 specification.
class SAEJ1979ModeTelemetry extends TelemetryMode {
  /// Creates a SAE J1979 telemetry controller.
  ///
  /// ### Parameters:
  /// - (AdapterOBD2): Active adapter instance.
  SAEJ1979ModeTelemetry();

  /// OBD-II service mode for live powertrain data.
  static const String mode = '01';

  @override
  final DetailedPID rpm = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010C',
    'Engine Revolutions Per Minute',
    '([0] * 256 + [1]) / 4',
  );

  @override
  final DetailedPID speed = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010D',
    'Vehicle Speed',
    '[0]',
  );

  final DetailedPID odometer = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '01A6',
    'Vehicle Odometer',
    '([0] * 16777216 + [1] * 65536 + [2] * 256 + [3]) / 10',
  );

  @override
  final DetailedPID coolantTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0105',
    'Engine Coolant Temperature',
    '[0] - 40',
  );

  @override
  final DetailedPID intakeAirTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010F',
    'Intake Air Temperature',
    '[0] - 40',
  );

  @override
  final DetailedPID throttlePosition = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0111',
    'Throttle Position',
    '[0] * 100 / 255',
  );

  @override
  final DetailedPID engineLoad = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0104',
    'Calculated Engine Load',
    '[0] * 100 / 255',
  );

  @override
  final DetailedPID massAirFlow = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0110',
    'Mass Air Flow',
    '([0] * 256 + [1]) / 100',
  );

  @override
  final DetailedPID fuelLevel = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '012F',
    'Fuel Level Input',
    '[0] * 100 / 255',
  );

  @override
  final DetailedPID intakeManifoldPressure = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010B',
    'Intake Manifold Pressure',
    '[0]',
  );

  @override
  final DetailedPID timingAdvance = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010E',
    'Timing Advance',
    '([0] / 2) - 64',
  );

  @override
  final DetailedPID barometricPressure = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0133',
    'Barometric Pressure',
    '[0]',
  );

  @override
  final DetailedPID controlModuleVoltage = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0142',
    'Control Module Voltage',
    '([0] * 256 + [1]) / 1000',
  );

  @override
  final DetailedPID oilTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '015C',
    'Engine Oil Temperature',
    '[0] - 40',
  );

  @override
  final DetailedPID fuelRate = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '015E',
    'Engine Fuel Rate',
    '([0] * 256 + [1]) / 20',
  );

  @override
  final DetailedPID ambientAirTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0146',
    'Ambient Air Temperature',
    '[0] - 40',
  );

  @override
  final DetailedPID fuelType = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0151',
    'Fuel Type',
    '[0]',
  );

  @override
  TelemetrySession stream({
    required List<DetailedPID> detailedPIDs,
    required void Function(Map<DetailedPID, double>) onData,
    Duration pollInterval = const Duration(milliseconds: 300),
    required AdapterOBD2 adapter,
  }) {
    if (!adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    int index = 0;

    final Timer pollingTimer = Timer.periodic(pollInterval, (_) async {
      if (!adapter.isConnected) return;

      final DetailedPID pid = detailedPIDs[index];
      index = (index + 1) % detailedPIDs.length;

      try {
        final double value = await adapter.queryPID(pid);
        onData({pid: value});
      } catch (error, stackTrace) {
        logError(
          error,
          stackTrace,
          message: 'Failed to poll telemetry data from the ECU.',
        );
      }
    });

    return TelemetrySession(pollingTimer);
  }

  @override
  Future<Map<DetailedPID, double>> query({
    required List<DetailedPID> detailedPIDs,
    required AdapterOBD2 adapter
  }) async {
    final Map<DetailedPID, double> results = {};

    for (final DetailedPID pid in detailedPIDs) {
      try {
        final double value = await adapter.queryPID(pid);
        results[pid] = value;
      } catch (error, stackTrace) {
        logError(
          error,
          stackTrace,
          message: 'Failed to query telemetry data from the ECU.',
        );
        rethrow;
      }
    }

    return results;
  }
}
