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
    obd2QueryReturnType: OBD2QueryReturnValue.composite,
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

  /// Contains a list of all supported PIDs.
  List<DetailedPID<dynamic>> get allDetailedPID => [
    rpm,
    speed,
    odometer,
    coolantTemperature,
    intakeAirTemperature,
    throttlePosition,
    engineLoad,
    massAirFlow,
    fuelLevel,
    intakeManifoldPressure,
    timingAdvance,
    lambdaBank1Sensor1,
    barometricPressure,
    controlModuleVoltage,
    oilTemperature,
    fuelRate,
    ambientAirTemperature,
    fuelType
  ];

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
    } catch (error, stack) {
      logError(error, stack, message: "Error calculating AFR from list data");
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
  Future<double> calculateOdometer({
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

    } catch (error, stack) {
      logError(
        error,
        stack,
        message: 'Failed to calculate GPS odometer.',
      );
      // Fallback: Return the original value to prevent data corruption
      return currentOdometer;
    }
  }

  /// Detects supported Mode 01 telemetry PIDs using a hybrid strategy.
  ///
  /// This method first queries the SAE J1979 capability bitmasks
  /// (0100, 0120, 0140) to determine which PIDs are theoretically supported
  /// by the ECU. It then optionally validates real-world accessibility
  /// by actively querying each supported PID.
  ///
  /// ### Parameters:
  /// - [adapter] (AdapterOBD2): A connected and initialized adapter.
  /// - [validateAccessibility] (bool): If `true`, each PID is actively queried
  ///   to ensure it responds with valid data. Defaults to `false`.
  ///
  /// ### Returns:
  /// - (`Future<List<String>>`): A list of supported PID parameter IDs
  ///   (e.g., `["010C", "010D", "012F"]`).
  ///
  /// ### Notes:
  /// - Bitmask detection is fast and standards-based.
  /// - Accessibility validation is slower but guarantees real usability.
  /// - Manufacturer-restricted PIDs may appear in bitmask results but fail validation.
  ///
  /// ### Usage:
  /// ```dart
  /// final supportedPIDs = await sae.detectSupportedTelemetry(
  ///   adapter: adapter,
  ///   validateAccessibility: true,
  /// );
  /// ```
  Future<List<String>> detectSupportedTelemetry({ required AdapterOBD2 adapter, bool validateAccessibility = false }) async {
    if (!adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    final List<String> supportedParameterIDs = [];

    /// SAE J1979 capability discovery PIDs
    final List<DetailedPID> capabilityPIDs = [
      const DetailedPID(
        DiagnosticStandardIDs.saeJ1979,
        '0100',
        'Supported PIDs 01–20',
        '',
        obd2QueryReturnType: OBD2QueryReturnValue.status,
      ),
      const DetailedPID(
        DiagnosticStandardIDs.saeJ1979,
        '0120',
        'Supported PIDs 21–40',
        '',
        obd2QueryReturnType: OBD2QueryReturnValue.status,
      ),
      const DetailedPID(
        DiagnosticStandardIDs.saeJ1979,
        '0140',
        'Supported PIDs 41–60',
        '',
        obd2QueryReturnType: OBD2QueryReturnValue.status,
      ),
    ];

    try {
      // Bitmask Discovery
      // Checks for all accessible pids including manufacturer-restricted ones
      for (final DetailedPID capabilityPID in capabilityPIDs) {
        final List<int>? bitmask = await adapter.queryPID(capabilityPID) as List<int>?;
        if (bitmask == null || bitmask.length < 4) continue;

        final int basePID = int.parse(capabilityPID.parameterID.substring(2), radix: 16);

        for (int byteIndex = 0; byteIndex < 4; byteIndex++) {
          for (int bitIndex = 0; bitIndex < 8; bitIndex++) {
            final bool supported = (bitmask[byteIndex] & (1 << (7 - bitIndex))) != 0;

            if (!supported) continue;

            final int pidOffset = (byteIndex * 8) + bitIndex + 1;
            final int supportedPIDValue = basePID + pidOffset;

            final String supportedPID = '01${supportedPIDValue.toRadixString(16).padLeft(2, '0').toUpperCase()}';

            final bool isImplemented = allDetailedPID.any(
              (DetailedPID detailedPID) => detailedPID.parameterID == supportedPID,
            );

            if (isImplemented && !supportedParameterIDs.contains(supportedPID) == true) {
              supportedParameterIDs.add(supportedPID);
            }
          }
        }
      }

      // Optional Accessibility Check
      if (validateAccessibility) {
        final List<String> validatedParameterIDs = [];

        for (final DetailedPID detailedPID in allDetailedPID) {
          if (!supportedParameterIDs.contains(detailedPID.parameterID) == true) continue;

          try {
            final dynamic value = await adapter.queryPID(detailedPID);
            if (value != null) validatedParameterIDs.add(detailedPID.parameterID);
          } catch (error, stack) {
            logError(error, stack, message: 'Accessibility validation failed for PID ${detailedPID.parameterID}.');
          }
        }

        return validatedParameterIDs;
      }

      return supportedParameterIDs;

    } catch (error, stack) {
      logError( error, stack, message: 'Hybrid telemetry detection failed.');
      return [];
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
              lastQueryTimestamps[pid] = DateTime.now().millisecondsSinceEpoch;
            }
          } catch (error, stack) {
            logError(error, stack, message: 'Telemetry polling error.');
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

  /// Maps a list of raw PID strings to their corresponding [DetailedPID] objects.
  ///
  /// This utility is used to convert simple identifiers (e.g., "010C") into
  /// full metadata objects required by the [stream] or [query] methods.
  ///
  /// ### Parameters:
  /// - [pIDList] (`List<String>`): A list of hex strings representing PIDs.
  ///
  /// ### Returns:
  /// - (`List<DetailedPID>`): A list of matching [DetailedPID] instances
  ///   found in [allDetailedPID].
  ///
  /// ### Usage:
  /// ```dart
  /// final pids = sae.getDetailedPIDsFromPIDList(["010C", "010D"]);
  /// ```
  List<DetailedPID> getDetailedPIDsFromPIDList(List<String> pIDList) {
    final List<DetailedPID> detailedPIDs = [];

    for (final String pid in pIDList) {
      // Find the first object where the parameterID matches the current pid
      final match = allDetailedPID.firstWhere(
        (detail) => detail.parameterID == pid,
        orElse: () => null as dynamic,
      );

      if (match != null) {
        detailedPIDs.add(match);
      }
    }

    return detailedPIDs;
  }

  /// Executes a one-time sequential query for a specific set of PIDs.
  ///
  /// Unlike [stream], this method performs a single pass through the
  /// provided list and returns a mapped result of the current values.
  ///
  /// ### Parameters:
  /// - [detailedPIDs]: The list of [DetailedPID] objects to fetch.
  /// - [adapter]: The active [AdapterOBD2] connection.
  ///
  /// ### Returns:
  /// - (`Future<Map<DetailedPID, dynamic>>`): A map where keys are the
  ///   requested PIDs and values are the decoded responses from the ECU.
  ///
  /// ### Throws:
  /// - [Exception]: Rethrows any communication errors encountered
  ///   during the query process.
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
      } catch (error, stack) {
        logError(
          error,
          stack,
          message: 'Failed to query telemetry data from the ECU for PID ${pid.parameterID}.',
        );
        rethrow;
      }
    }

    return results;
  }
}

