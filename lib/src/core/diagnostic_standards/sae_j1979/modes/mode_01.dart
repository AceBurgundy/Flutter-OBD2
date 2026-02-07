import 'dart:async';

import 'package:obd2/src/functions.dart';
import '../../../../enums.dart';
import '../../../../models.dart';
import '../../../adapter_obd2.dart';
import '../../../standard_ids.dart';
import '../../modes_abstract/mode_01.dart';


/// SAE = Society of Automotive Engineers
/// PID = Parameter Identifier
/// ECU = Engine Control Unit
/// AFR = Air Fuel Ratio
/// DTC = Diagnostic Trouble Code
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
  final DetailedPID<double> rpm = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010C',
    'Engine Revolutions Per Minute',
    '([0] * 256 + [1]) / 4',
    bestPollingIntervalMs: 10
  );

  @override
  final DetailedPID<double> speed = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010D',
    'Vehicle Speed',
    '[0]',
  );

  @override
  final DetailedPID<double> odometer = const DetailedPID(
      DiagnosticStandardIDs.saeJ1979,
    '01A6',
    'Vehicle Odometer',
    '([0] * 16777216 + [1] * 65536 + [2] * 256 + [3]) / 10',
      bestPollingIntervalMs: 10000
  );

  @override
  final DetailedPID<double> coolantTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0105',
    'Engine Coolant Temperature',
    '[0] - 40',
    bestPollingIntervalMs: 5000
  );

  @override
  final DetailedPID<double> intakeAirTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010F',
    'Intake Air Temperature',
    '[0] - 40',
    bestPollingIntervalMs: 2000
  );

  @override
  final DetailedPID<double> throttlePosition = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0111',
    'Throttle Position',
    '[0] * 100 / 255',
  );

  @override
  final DetailedPID<double> engineLoad = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0104',
    'Calculated Engine Load',
    '[0] * 100 / 255',
  );

  @override
  final DetailedPID<double> massAirFlow = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0110',
    'Mass Air Flow',
    '([0] * 256 + [1]) / 100',
  );

  @override
  final DetailedPID<double> fuelLevel = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '012F',
    'Fuel Level Input',
    '[0] * 100 / 255',
    bestPollingIntervalMs: 10000
  );

  @override
  final DetailedPID<double> intakeManifoldPressure = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010B',
    'Intake Manifold Pressure',
    '[0]',
  );

  @override
  final DetailedPID<double> timingAdvance = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010E',
    'Timing Advance',
    '([0] / 2) - 64',
  );

  /// Lambda (Equivalence Ratio) and Voltage.
  ///
  /// This PID returns a composite list of two values:
  /// - Index 0: Lambda (Equivalence Ratio)
  /// - Index 1: Sensor Voltage
  @override
  final DetailedPID<List<double>> lambdaBank1Sensor1 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    "0124",
    "Lambda (Bank 1, Sensor 1)",
    "(256 * A + B) / 32768",
    obd2QueryReturnType: OBD2QueryReturnValue.composite, // Tells adapter to return List<double>
  );

  @override
  final DetailedPID<double> barometricPressure = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0133',
    'Barometric Pressure',
    '[0]',
  );

  @override
  final DetailedPID<double> controlModuleVoltage = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0142',
    'Control Module Voltage',
    '([0] * 256 + [1]) / 1000',
    bestPollingIntervalMs: 1000
  );

  @override
  final DetailedPID<double> oilTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '015C',
    'Engine Oil Temperature',
    '[0] - 40',
  );

  @override
  final DetailedPID<double> fuelRate = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '015E',
    'Engine Fuel Rate',
    '([0] * 256 + [1]) / 20',
  );

  @override
  final DetailedPID<double> ambientAirTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0146',
    'Ambient Air Temperature',
    '[0] - 40',
    bestPollingIntervalMs: 10000
  );

  @override
  final DetailedPID<String> fuelType = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0151',
    'Fuel Type',
    '[0]',
    obd2QueryReturnType: OBD2QueryReturnValue.text,
    bestPollingIntervalMs: 60000
  );

  /// Calculates AFR (Air Fuel Ratio) from the Lambda vector.
  ///
  /// Expects the list returned by [lambdaBank1Sensor1] which contains
  /// [Lambda, Voltage].
  ///
  /// ### Parameters:
  /// - [lambdaData] (`List<double>`): The composite result from PID 0124.
  /// - [fuelStoichiometricRatio] (double): The stoichiometric ratio for the fuel.
  ///    - Gasoline: 14.7 (Default)
  ///    - Diesel: 14.5
  ///    - E85 Ethanol: 9.76
  ///
  /// ### Returns:
  /// - (double): The calculated Air-Fuel Ratio (e.g., 14.7).
  ///
  /// ### Usage:
  /// ```dart
  /// double afr = sae.calculateAFR(resultList);
  /// ```
  double calculateAFR(List<double> lambdaData, {double fuelStoichiometricRatio = 14.7}) {
    try {
      if (lambdaData.isEmpty) return 0.0;

      // Extract Lambda from the first index of the list
      double lambdaValue = lambdaData[0];

      // Convert to AFR
      return lambdaValue * fuelStoichiometricRatio;
    } catch (error, stackTrace) {
      logError(error, stackTrace, message: "Error calculating AFR from list data");
      return 0.0;
    }
  }

  /// Calculates the projected odometer reading based on speed and elapsed time.
  ///
  /// This method uses dead-reckoning to estimate the distance traveled since the
  /// [lastUpdateTime]. It includes a specific filter to ignore GPS "drift"
  /// inaccuracies when the vehicle is stationary or moving very slowly (e.g., < 3 km/h).
  ///
  /// ### Parameters:
  /// - (`double` currentOdometer): The last known odometer reading in kilometers.
  /// - (`double` currentSpeedKmh): The current vehicle speed in km/h (usually from GPS).
  /// - (`DateTime` lastUpdateTime): The timestamp when the odometer was last updated.
  ///
  /// ### Returns:
  /// - (`Future<double>`): The updated odometer reading in kilometers. If permissions
  ///   are denied or an error occurs, returns the original [currentOdometer].
  ///
  /// ### Usage:
  /// ```dart
  /// double newOdo = await SAEJ1979ModeTelemetry.calculateOdometer(
  ///   currentOdometer: vehicle.odometer,
  ///   currentSpeedKmh: gpsSpeed,
  ///   lastUpdateTime: lastTickTime,
  /// );
  /// ```
  static Future<double> calculateOdometer({
    required double currentOdometer,
    required double currentSpeedKmh,
    required DateTime lastUpdateTime,
  }) async {
    // GPS: Global Positioning System
    // KMH: Kilometers Per Hour

    // Threshold to filter out GPS drift when stopped.
    // GPS often reports 1-3 km/h even when completely stationary.
    const double gpsStationaryThresholdKmh = 3.0;

    try {
      // 2. Filter GPS Noise
      // If the speed is too low, we assume the vehicle is stopped and
      // simply return the current odometer without incrementing.
      if (currentSpeedKmh < gpsStationaryThresholdKmh) {
        return currentOdometer;
      }

      // 3. Calculate Time Delta
      final DateTime now = DateTime.now();
      final Duration timeDifference = now.difference(lastUpdateTime);

      // Convert duration to hours (milliseconds / 1000 / 60 / 60)
      final double elapsedHours = timeDifference.inMilliseconds / 3600000.0;

      // 4. Calculate Distance Traveled (Distance = Speed * Time)
      final double distanceTraveledKm = currentSpeedKmh * elapsedHours;

      // 5. Return Incremented Odometer
      return currentOdometer + distanceTraveledKm;

    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to calculate GPS odometer.',
      );
      // Fallback: Return the original value to prevent data corruption
      return currentOdometer;
    }
  }

  /// Starts a live telemetry streaming session using a robust recursive loop.
  ///
  /// This implementation uses a "wait-and-proceed" approach instead of a fixed Timer.
  /// This ensures that if a PID times out, the next request waits patiently
  /// instead of causing a collision.
  ///
  /// ### Parameters:
  /// - [detailedPIDs]: A list of Parameter IDs to be polled.
  /// - [onData]: A callback triggered when new telemetry data is received.
  /// - [adapter]: The physical or virtual adapter used for communication.
  /// - [pollIntervalMs]: The delay in milliseconds between each request.
  ///
  /// ### Returns:
  /// - (TelemetrySession): An object allowing the user to control or stop the stream.
  ///
  /// ### Usage:
  /// ```dart
  /// final session = manager.stream(
  ///   detailedPIDs: [rpmPid, speedPid],
  ///   onData: (data) => print(data),
  ///   adapter: myAdapter,
  /// );
  /// ```
  ///
  /// ### Throws:
  /// - (StateError): Thrown if the adapter is not connected when the stream starts.
  @override
  @override
  TelemetrySession stream({
    required List<DetailedPID> detailedPIDs,
    required void Function(TelemetryData) onData,
    required AdapterOBD2 adapter,
    int pollIntervalMs = 10,
  }) {
    if (!adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    final Map<DetailedPID, int> lastQueryTimestamps = {
      for (var pid in detailedPIDs) pid: 0
    };

    bool isRunning = true;
    int index = 0;

    Future<void> smartLoop() async {
      while (isRunning && adapter.isConnected) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final pid = detailedPIDs[index];
        index = (index + 1) % detailedPIDs.length;

        final lastTime = lastQueryTimestamps[pid]!;
        final targetInterval = pid.bestPollingIntervalMs;

        if (now - lastTime >= targetInterval) {
          try {
            final value = await adapter.queryPID(pid);
            if (isRunning) {
              onData(TelemetryData({pid: value}));
              lastQueryTimestamps[pid] =
                  DateTime.now().millisecondsSinceEpoch;
            }
          } catch (error, stackTrace) {
            logError(error, stackTrace,
                message: 'Telemetry polling error.');
          }
        }

        await Future.delayed(Duration(milliseconds: pollIntervalMs));
      }
    }

    smartLoop();

    return TelemetrySession(() {
      isRunning = false;
    });
  }

  @override
  Future<Map<DetailedPID, dynamic>> query({
    required List<DetailedPID> detailedPIDs,
    required AdapterOBD2 adapter,
  }) async {
    final Map<DetailedPID, dynamic> results = {};

    for (final DetailedPID pid in detailedPIDs) {
      try {
        final dynamic value = await adapter.queryPID(pid);
        results[pid] = value;
      } catch (error, stackTrace) {
        logError(
          error,
          stackTrace,
          message: 'Failed to query telemetry data from the ECU for PID ${pid.parameterID}.',
        );
        rethrow;
      }
    }

    return results;
  }
}

