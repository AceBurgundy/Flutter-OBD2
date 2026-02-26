import 'dart:async';

import '../../../obd2.dart';
import '../adapter_series/adapter_obd2.dart';
import '../standard_ids.dart';

/// SAE = Society of Automotive Engineers
/// PID = Parameter Identifier
/// ECU = Engine Control Unit
/// AFR = Air Fuel Ratio
/// DTC = Diagnostic Trouble Code
/// GPS = Global Positioning System
/// EMA = Exponential Moving Average
/// EDF = Earliest Deadline First
/// QPS = Queries Per Second

/// Represents a scheduled telemetry task used by the internal scheduler.
///
/// Each scheduled task corresponds to a single [DetailedPID] and maintains:
/// - The associated PID metadata
/// - Its fixed polling interval
/// - The next execution timestamp in epoch milliseconds
///
/// This class is strictly internal and used by the Min-Heap scheduler
/// to implement an Earliest Deadline First (EDF) scheduling strategy.
///
/// In EDF scheduling:
/// The task with the smallest [nextDueTimeMilliseconds] is executed first.
class _ScheduledTelemetryTask {

  /// The PID metadata associated with this scheduled task.
  ///
  /// This defines:
  /// - The parameter ID (e.g., "010C")
  /// - The decoding formula
  /// - Units
  /// - Best polling interval
  final DetailedPID detailedPID;

  /// Polling interval in milliseconds.
  ///
  /// This represents the desired time between successive executions.
  final int intervalMilliseconds;

  /// The next time (in epoch milliseconds) that this PID should execute.
  ///
  /// This value is dynamically updated after every execution.
  int nextDueTimeMilliseconds;

  /// Creates a scheduled telemetry task.
  ///
  /// ### Parameters:
  /// - [detailedPID]: The PID metadata.
  /// - [intervalMilliseconds]: Polling interval in milliseconds.
  /// - [nextDueTimeMilliseconds]: First execution timestamp.
  _ScheduledTelemetryTask({
    required this.detailedPID, required this.intervalMilliseconds, required this.nextDueTimeMilliseconds
  });
}

/// Lightweight Min-Heap (Priority Queue) implementation.
///
/// This heap is sorted by [nextDueTimeMilliseconds].
///
/// Complexity:
/// - O(log n) insertion
/// - O(log n) removal
/// - O(1) access to earliest task
///
/// The earliest scheduled task is always located at index 0.
class _TelemetryMinHeap {

  /// Internal heap storage.
  ///
  /// Maintains the heap property based on [nextDueTimeMilliseconds].
  final List<_ScheduledTelemetryTask> _heap = [];

  /// Returns whether the heap is empty.
  bool get isEmpty => _heap.isEmpty;

  /// Returns the earliest scheduled task without removing it.
  _ScheduledTelemetryTask get first => _heap.first;

  /// Adds a new task to the heap.
  ///
  /// Complexity: O(log n)
  void add(_ScheduledTelemetryTask scheduledTelemetryTask) {
    _heap.add(scheduledTelemetryTask);
    _bubbleUp(_heap.length - 1);
  }

  /// Removes and returns the earliest scheduled task.
  ///
  /// Complexity: O(log n)
  _ScheduledTelemetryTask removeFirst() {
    final _ScheduledTelemetryTask firstTask = _heap.first;
    final _ScheduledTelemetryTask lastTask = _heap.removeLast();

    if (_heap.isNotEmpty) {
      _heap[0] = lastTask;
      _bubbleDown(0);
    }

    return firstTask;
  }

  /// Restores heap ordering by moving a node upward.
  ///
  /// This method compares the current node with its parent and swaps
  /// them if the current node has an earlier due time.
  ///
  /// ### Parameters:
  /// - [index]: Index of the node to bubble upward.
  void _bubbleUp(int index) {
    while (index > 0) {
      final int parentIndex = (index - 1) ~/ 2;

      if (_heap[index].nextDueTimeMilliseconds >= _heap[parentIndex].nextDueTimeMilliseconds) {
        break;
      }

      final _ScheduledTelemetryTask temporary = _heap[index];
      _heap[index] = _heap[parentIndex];
      _heap[parentIndex] = temporary;
      index = parentIndex;
    }
  }

  /// Restores heap ordering by moving a node downward.
  ///
  /// This method selects the smallest child and swaps if necessary.
  ///
  /// ### Parameters:
  /// - [index]: Index of the node to bubble downward.
  void _bubbleDown(int index) {
    while (true) {
      final int leftChildIndex = index * 2 + 1;
      final int rightChildIndex = index * 2 + 2;
      int smallestIndex = index;

      if (leftChildIndex < _heap.length && _heap[leftChildIndex].nextDueTimeMilliseconds < _heap[smallestIndex].nextDueTimeMilliseconds) {
        smallestIndex = leftChildIndex;
      }

      if (rightChildIndex < _heap.length && _heap[rightChildIndex].nextDueTimeMilliseconds < _heap[smallestIndex].nextDueTimeMilliseconds) {
        smallestIndex = rightChildIndex;
      }

      if (smallestIndex == index) break;

      final _ScheduledTelemetryTask temporary = _heap[index];
      _heap[index] = _heap[smallestIndex];
      _heap[smallestIndex] = temporary;
      index = smallestIndex;
    }
  }
}

/// Represents an active telemetry polling session.
///
/// This class provides safe cancellation control for the scheduler loop.
class TelemetrySession {

  /// Internal stop callback used to terminate the scheduler loop.
  final void Function() _onStopCallback;

  /// Creates a telemetry session.
  TelemetrySession(this._onStopCallback);

  /// Stops the telemetry session.
  ///
  /// This method flips the internal running flag and
  /// safely terminates the scheduler loop.
  void stop() {
    _onStopCallback();
  }
}

/// SAE J1979 Mode 01 telemetry implementation.
///
/// Provides access to standard live powertrain telemetry
/// defined by the SAE J1979 specification.
class Telemetry {

  final AdapterOBD2 _adapter;

  /// Creates a SAE J1979 telemetry controller.
  ///
  /// ### Parameters:
  /// - (AdapterOBD2): Active adapter instance.
  Telemetry(this._adapter);

  /// OBD-II service mode for live powertrain data.
  static const String mode = '01';

  static final DetailedPID<double> rpm = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010C',
    'Engine Revolutions Per Minute',
    '([0] * 256 + [1]) / 4',
    pollingIntervalMs: 10
  );

  static final DetailedPID<double> speed = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010D',
    'Vehicle Speed',
    '[0]',
  );

  static final DetailedPID<double> odometer = const DetailedPID(
      DiagnosticStandardIDs.saeJ1979,
    '01A6',
    'Vehicle Odometer',
    '([0] * 16777216 + [1] * 65536 + [2] * 256 + [3]) / 10',
      pollingIntervalMs: 10000
  );

  static final DetailedPID<double> coolantTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0105',
    'Engine Coolant Temperature',
    '[0] - 40',
    pollingIntervalMs: 5000
  );

  static final DetailedPID<double> intakeAirTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010F',
    'Intake Air Temperature',
    '[0] - 40',
    pollingIntervalMs: 2000
  );

  static final DetailedPID<double> throttlePosition = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0111',
    'Throttle Position',
    '[0] * 100 / 255',
  );

  static final DetailedPID<double> engineLoad = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0104',
    'Calculated Engine Load',
    '[0] * 100 / 255',
  );

  static final DetailedPID<double> massAirFlow = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0110',
    'Mass Air Flow',
    '([0] * 256 + [1]) / 100',
  );

  static final DetailedPID<double> fuelLevel = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '012F',
    'Fuel Level Input',
    '[0] * 100 / 255',
    pollingIntervalMs: 10000
  );

  static final DetailedPID<double> intakeManifoldPressure = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010B',
    'Intake Manifold Pressure',
    '[0]',
  );

  static final DetailedPID<double> timingAdvance = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '010E',
    'Timing Advance',
    '([0] / 2) - 64',
  );

  /// Lambda (Equivalence Ratio) and Voltage.
  ///
  /// This PID returns a composite list of two values:
  /// - Index 0: Lambda (Equivalence Ratio)
  ///
  static final DetailedPID<List<double>> lambdaBank1Sensor1 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    "0124",
    "Lambda (Bank 1, Sensor 1)",
    "(256 * A + B) / 32768",
    obd2QueryReturnType: QueryReturnValue.composite,
  );

  static final DetailedPID<double> barometricPressure = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0133',
    'Barometric Pressure',
    '[0]',
  );

  static final DetailedPID<double> oilTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '015C',
    'Engine Oil Temperature',
    '[0] - 40',
  );

  static final DetailedPID<double> fuelRate = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '015E',
    'Engine Fuel Rate',
    '([0] * 256 + [1]) / 20',
  );

  static final DetailedPID<double> ambientAirTemperature = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0146',
    'Ambient Air Temperature',
    '[0] - 40',
    pollingIntervalMs: 10000
  );

  static final DetailedPID<String> fuelType = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0151',
    'Fuel Type',
    '[0]',
    obd2QueryReturnType: QueryReturnValue.text,
    pollingIntervalMs: 60000
  );

  /// STFT = Short Term Fuel Trim
  static final DetailedPID<double> shortTermFuelTrimBank1 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0106',
    'Short Term Fuel Trim (Bank 1)',
    '([0] * 100 / 128) - 100',
    unit: 'percent',
  );

  /// LTFT = Long Term Fuel Trim
  static final DetailedPID<double> longTermFuelTrimBank1 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0107',
    'Long Term Fuel Trim (Bank 1)',
    '([0] * 100 / 128) - 100',
    unit: 'percent',
  );

  static final DetailedPID<double> shortTermFuelTrimBank2 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0108',
    'Short Term Fuel Trim (Bank 2)',
    '([0] * 100 / 128) - 100',
    unit: 'percent',
  );

  static final DetailedPID<double> longTermFuelTrimBank2 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0109',
    'Long Term Fuel Trim (Bank 2)',
    '([0] * 100 / 128) - 100',
    unit: 'percent',
  );

  /// FRP = Fuel Rail Pressure (Relative)
  static final DetailedPID<double> fuelRailPressureRelative = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0122',
    'Fuel Rail Pressure (Relative)',
    '([0] * 256 + [1]) * 0.079',
    unit: 'kPa',
  );

  /// FRP = Fuel Rail Pressure (Absolute)
  static final DetailedPID<double> fuelRailPressureAbsolute = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0123',
    'Fuel Rail Pressure (Absolute)',
    '([0] * 256 + [1]) * 10',
    unit: 'kPa',
  );

  /// CAT = Catalyst Temperature
  static final DetailedPID<double> catalystTemperatureBank1Sensor1 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '013C',
    'Catalyst Temperature (Bank 1, Sensor 1)',
    '(([0] * 256 + [1]) / 10) - 40',
    unit: 'celsius',
  );

  static final DetailedPID<double> catalystTemperatureBank2Sensor1 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '013D',
    'Catalyst Temperature (Bank 2, Sensor 1)',
    '(([0] * 256 + [1]) / 10) - 40',
    unit: 'celsius',
  );

  static final DetailedPID<double> catalystTemperatureBank1Sensor2 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '013E',
    'Catalyst Temperature (Bank 1, Sensor 2)',
    '(([0] * 256 + [1]) / 10) - 40',
    unit: 'celsius',
  );

  static final DetailedPID<double> catalystTemperatureBank2Sensor2 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '013F',
    'Catalyst Temperature (Bank 2, Sensor 2)',
    '(([0] * 256 + [1]) / 10) - 40',
    unit: 'celsius',
  );

  /// LOAD = Absolute Engine Load
  static final DetailedPID<double> absoluteLoad = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0143',
    'Absolute Engine Load',
    '([0] * 256 + [1]) * 100 / 255',
    unit: 'percent',
  );

  /// EVAP = Evaporative Emission System Vapor Pressure
  static final DetailedPID<double> evapVaporPressure = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0132',
    'Evaporative System Vapor Pressure',
    '(([0] * 256 + [1]) / 4) - 8192',
    unit: 'Pa',
  );

  static final DetailedPID<double> evapVaporPressureAlt = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0153',
    'Evaporative System Vapor Pressure (Alt)',
    '([0] * 256 + [1]) / 200',
    unit: 'kPa',
  );

  /// WUC = Warm-Up Cycles Since DTC Cleared
  static final DetailedPID<double> warmUpCyclesSinceDtcCleared = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0130',
    'Warm-Up Cycles Since DTC Cleared',
    '[0]',
    unit: 'count',
  );

  /// MIL = Malfunction Indicator Lamp Distance
  static final DetailedPID<double> distanceWithMilOn = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0121',
    'Distance Traveled with MIL On',
    '([0] * 256 + [1])',
    unit: 'km',
  );

  /// MIL = Malfunction Indicator Lamp Time
  static final DetailedPID<double> timeWithMilOn = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '014D',
    'Engine Run Time with MIL On',
    '([0] * 256 + [1])',
    unit: 'minutes',
  );

  /// DTC = Diagnostic Trouble Code Runtime
  static final DetailedPID<double> engineRunTimeSinceDtcCleared = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '014E',
    'Engine Run Time Since DTC Cleared',
    '([0] * 256 + [1])',
    unit: 'minutes',
  );

  /// O2 = Oxygen Sensor (Bank 1 Sensor 1)
  static final DetailedPID<List<double>> o2Bank1Sensor1 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0114',
    'O2 Sensor (Bank 1, Sensor 1)',
    '',
    unit: 'volt/percent',
    obd2QueryReturnType: QueryReturnValue.composite,
  );

  static final DetailedPID<List<double>> o2Bank1Sensor2 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0115',
    'O2 Sensor (Bank 1, Sensor 2)',
    '',
    unit: 'volt/percent',
    obd2QueryReturnType: QueryReturnValue.composite,
  );

  static final DetailedPID<List<double>> o2Bank2Sensor1 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0118',
    'O2 Sensor (Bank 2, Sensor 1)',
    '',
    unit: 'volt/percent',
    obd2QueryReturnType: QueryReturnValue.composite,
  );

  static final DetailedPID<List<double>> o2Bank2Sensor2 = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0119',
    'O2 Sensor (Bank 2, Sensor 2)',
    '',
    unit: 'volt/percent',
    obd2QueryReturnType: QueryReturnValue.composite,
  );

  /// MIL = Malfunction Indicator Lamp & DTC Count
  static final DetailedPID<List<int>> monitorStatusSinceClear = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0101',
    'Monitor Status Since DTC Cleared',
    '',
    unit: 'bitfield',
    obd2QueryReturnType: QueryReturnValue.status,
  );

  static final DetailedPID<List<int>> monitorStatusThisDriveCycle = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0141',
    'Monitor Status This Drive Cycle',
    '',
    unit: 'bitfield',
    obd2QueryReturnType: QueryReturnValue.status,
  );

  /// CMV = Control Module Voltage
  static final DetailedPID<double> controlModuleVoltage = const DetailedPID(
    DiagnosticStandardIDs.saeJ1979,
    '0142',
    'Control Module Voltage',
    '([0] * 256 + [1]) / 1000',
    unit: 'volts',
  );

  /// Contains a list of all supported PIDs.
  static List<DetailedPID<dynamic>> get allDetailedPIDs => [
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
    oilTemperature,
    fuelRate,
    ambientAirTemperature,
    fuelType,
    shortTermFuelTrimBank1,
    longTermFuelTrimBank1,
    shortTermFuelTrimBank2,
    longTermFuelTrimBank2,
    fuelRailPressureRelative,
    fuelRailPressureAbsolute,
    catalystTemperatureBank1Sensor1,
    catalystTemperatureBank2Sensor1,
    catalystTemperatureBank1Sensor2,
    catalystTemperatureBank2Sensor2,
    absoluteLoad,
    evapVaporPressure,
    evapVaporPressureAlt,
    warmUpCyclesSinceDtcCleared,
    distanceWithMilOn,
    timeWithMilOn,
    engineRunTimeSinceDtcCleared,
    o2Bank1Sensor1,
    o2Bank1Sensor2,
    o2Bank2Sensor1,
    o2Bank2Sensor2,
    monitorStatusSinceClear,
    monitorStatusThisDriveCycle,
    controlModuleVoltage
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
      final double lambdaValue = lambdaData[0];

      // Convert to AFR
      return lambdaValue * fuelStoichiometricRatio;
    } catch (error) {
      // If an error occurs (e.g. invalid data), simply return 0.0
      return 0.0;
    }
  }

  /// Detects supported Mode 01 telemetry Parameter IDs using SAE J1979 capability bitmasks.
  ///
  /// This method queries the ECU using the standardized "Supported PIDs"
  /// discovery mechanism defined in SAE J1979.
  ///
  /// The ECU exposes supported Parameter IDs in 32-PID blocks:
  ///
  /// - 0100 → Supports PIDs 01–20
  /// - 0120 → Supports PIDs 21–40
  /// - 0140 → Supports PIDs 41–60
  /// - 0160 → Supports PIDs 61–80
  /// - 0180 → Supports PIDs 81–A0
  ///
  /// Each query returns a 4-byte bitmask:
  ///
  /// - 4 bytes × 8 bits = 32 bits
  /// - Each bit represents support for one Parameter ID
  ///
  /// Bit position logic:
  ///
  /// ```
  /// Parameter ID Offset = (byteIndex * 8) + bitIndex + 1
  /// Final Parameter ID = base + Offset
  /// ```
  ///
  /// After extracting supported Parameter IDs from the ECU,
  /// this method filters them against the locally defined
  /// [allDetailedPID] list to ensure only supported and implemented
  /// Parameter IDs are returned.
  ///
  /// ### Bitmask Decoding
  ///
  /// Each bit is evaluated using:
  ///
  /// ```dart
  /// (byte & (1 << (7 - bitIndex))) != 0
  /// ```
  ///
  /// Bits are read from Most Significant Bit (MSB) to Least Significant Bit (LSB)
  /// as defined by the SAE specification.
  ///
  /// ### Accessibility Validation
  ///
  /// The [validateAccessibility] flag is reserved for future expansion,
  /// where each detected Parameter ID could be actively queried to confirm
  /// real-world accessibility (some ECUs advertise unsupported PIDs).
  ///
  ///
  /// ### Parameters:
  /// - (`bool` validateAccessibility):
  ///   If true, future implementations may validate each detected Parameter ID
  ///   by actively querying it. Default: false.
  ///
  /// ### Returns:
  /// - (`Future<List<String>>`):
  ///   A list of supported Parameter ID hex strings (e.g., ["010C", "010D"]).
  ///
  /// ### Usage:
  /// ```dart
  /// final supportedParameterIDs = await telemetry.findSupportedIDs();
  /// ```
  ///
  /// ### Throws:
  /// - (`StateError`): If the adapter is not connected.
  ///
  Future<List<String>> detectSupportedTelemetry({bool validateAccessibility = false}) async {

    // Ensure adapter connection before attempting ECU communication.
    if (!_adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    // List of supported Parameter ID hex strings.
    final List<String> supportedParameterIDs = [];

    // Iterate through 32-PID capability blocks.
    // Each iteration represents a base block:
    // 0x00, 0x20, 0x40, 0x60, 0x80, 0xA0
    for (int base = 0x00; base <= 0xA0; base += 0x20) {

      // Construct capability query hex string.
      // Example:
      // base = 0x00 → "0100"
      // base = 0x20 → "0120"
      final String parameterIDHex = '01${base.toRadixString(16).padLeft(2, '0').toUpperCase()}';

      // Create temporary DetailedPID to query capability bitmask.
      final DetailedPID<List<int>> capabilityParameterID = DetailedPID<List<int>>(
        DiagnosticStandardIDs.saeJ1979,
        parameterIDHex,
        'Supported Parameter IDs',
        '',
        obd2QueryReturnType: QueryReturnValue.status,
      );

      // Query ECU for 4-byte bitmask response.
      final List<int>? bitmask = await _adapter.queryPID(capabilityParameterID) as List<int>?;

      // Defensive check:
      // If response is null or incomplete, skip this block.
      if (bitmask == null || bitmask.length < 4) continue;

      // Iterate through each byte (4 total).
      for (int byteIndex = 0; byteIndex < 4; byteIndex++) {

        // Iterate through each bit within the byte (8 bits).
        for (int bitIndex = 0; bitIndex < 8; bitIndex++) {

          // Determine whether this specific bit indicates support.
          //
          // 1 << (7 - bitIndex)
          // Reads bits from MSB to LSB.
          final bool isSupportedBit = (bitmask[byteIndex] & (1 << (7 - bitIndex))) != 0;

          if (!isSupportedBit) continue;

          /// Parameter ID off set calculation
          ///
          /// For each set bit:
          ///
          /// Offset =
          ///     (byteIndex * 8) + bitIndex + 1
          ///
          /// +1 because PID numbering starts at 1 within each block.
          ///
          final int parameterIDOffset = (byteIndex * 8) + bitIndex + 1;

          // Final Parameter ID numeric value.
          final int parameterIDValue = base + parameterIDOffset;

          // Convert numeric value to full Mode 01 hex string.
          final String fullParameterID = '01${parameterIDValue.toRadixString(16).padLeft(2, '0').toUpperCase()}';

          // Filter against locally implemented PIDs.
          // Ensures only supported AND implemented Parameter IDs are returned.
          bool inLocalCollection = allDetailedPIDs.any(
            (detailedPID) => detailedPID.parameterID == fullParameterID
          );

          if (inLocalCollection) {
            supportedParameterIDs.add(fullParameterID);
          }
        }
      }
    }

    return supportedParameterIDs;
  }

  /// Starts an advanced telemetry streaming session.
  ///
  /// This method creates a continuously running telemetry scheduler
  /// that polls the ECU using an adaptive, rate-limited, and latency-aware system.
  ///
  /// ### Core Architecture
  ///
  /// 1. Earliest Deadline First (EDF) Scheduler
  ///    - Implemented using a Min-Heap.
  ///    - The PID with the smallest `nextDueTimeMilliseconds` executes first.
  ///    - Prevents burst execution.
  ///    - Guarantees O(log n) scheduling complexity.
  ///
  /// 2. Token Bucket Governor
  ///    - Limits maximum queries per second (QPS).
  ///    - Prevents adapter overload and Bluetooth buffer congestion.
  ///    - Each query consumes exactly one token.
  ///    - Tokens refill proportionally over time.
  ///
  /// 3. Exponential Moving Average (EMA) Latency Tracking
  ///    - Measures real ECU query latency.
  ///    - Smooths noise.
  ///    - Prevents aggressive oscillation.
  ///
  ///      Formula:
  ///      newAverage = oldAverage * (1 - α) + newLatency * α
  ///
  /// 4. Adaptive Spacing
  ///    - Adds a latency-based spacing delay after each execution.
  ///    - Prevents overlapping ECU commands.
  ///    - Automatically scales with adapter speed.
  ///
  /// ### Micro-Optimizations (High-Frequency Telemetry)
  ///
  /// This implementation reduces per-iteration overhead by:
  ///
  /// - Caching time conversions
  /// - Precomputing EMA coefficients
  /// - Avoiding repeated `.toDouble()` conversions
  /// - Reducing system clock calls
  /// - Minimizing heap dereferencing
  ///
  /// These optimizations matter when:
  /// - Polling < 20ms intervals
  /// - Streaming 10+ PIDs
  /// - Running on mobile CPUs
  /// - Using Bluetooth adapters
  ///
  /// ### Parameters:
  /// - [detailedPIDs] (`List<DetailedPID>`): required List of PIDs to stream.
  /// - [onData] (`void Function(TelemetryData)`): Callback invoked every time a PID returns data.
  /// - [maxQueriesPerSecond] (`int`=25): Hard safety cap on query rate.
  /// - [latencySmoothingFactor] (`double`):
  ///     double EMA smoothing coefficient.
  ///     Range: 0.0–1.0
  ///     Lower = more stable
  ///     Higher = more reactive
  ///
  /// ### Returns
  /// - (`TelemetrySession`): Allows caller to stop the scheduler safely.
  ///
  /// ### Throws
  /// - (`StateError`): If adapter is not connected.
  ///
  TelemetrySession stream({
    required List<DetailedPID> detailedPIDs,
    required void Function(TelemetryData) onData,
    int maxQueriesPerSecond = 25,
    double latencySmoothingFactor = 0.2,
  }) {
    // Prevent undefined behavior if adapter is disconnected.
    if (!_adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    // Min-Heap implementing Earliest Deadline First scheduling.
    final _TelemetryMinHeap heap = _TelemetryMinHeap();

    // Initialize all tasks as immediately due.
    // They will naturally stagger after first execution.
    final int startTimeMilliseconds = DateTime.now().millisecondsSinceEpoch;

    for (final DetailedPID detailedPID in detailedPIDs) {
      heap.add(
        _ScheduledTelemetryTask(
          detailedPID: detailedPID,
          intervalMilliseconds: detailedPID.pollingIntervalMs,
          nextDueTimeMilliseconds: startTimeMilliseconds,
        ),
      );
    }

    /// Token Bucket Governor

    // Convert once to double to avoid repeated conversions.
    final double maximumTokens = maxQueriesPerSecond.toDouble();

    // Current available permits.
    double tokens = maximumTokens;

    // Tokens regenerated per second.
    final double refillRatePerSecond = maximumTokens;

    // Tracks last refill timestamp.
    int lastRefillTimestampMilliseconds = startTimeMilliseconds;

    /// Adaptive Latency Tracking

    // EMA running average.
    double averageLatencyMilliseconds = 10.0;

    // Precompute retention factor to avoid repeated subtraction.
    final double latencyRetentionFactor = 1.0 - latencySmoothingFactor;

    // Precompute milliseconds-to-seconds conversion constant.
    const double millisecondsToSeconds = 1.0 / 1000.0;

    bool isRunning = true;

    Future<void> schedulerLoop() async {
      while (isRunning && _adapter.isConnected) {

        if (heap.isEmpty) break;

        // Capture current time ONCE per loop iteration.
        final int nowMilliseconds = DateTime.now().millisecondsSinceEpoch;

        /// Token Refill Step
        ///
        /// elapsedSeconds =
        ///     (currentTime - lastRefillTime) / 1000
        ///
        /// Multiply instead of divide to reduce cost.
        ///
        final double elapsedSeconds = (nowMilliseconds - lastRefillTimestampMilliseconds) * millisecondsToSeconds;

        tokens += elapsedSeconds * refillRatePerSecond;

        // Prevent bucket overflow.
        if (tokens > maximumTokens) tokens = maximumTokens;

        lastRefillTimestampMilliseconds = nowMilliseconds;

        final _ScheduledTelemetryTask scheduledTelemetryTask = heap.first;

        /// Deadline Check
        ///
        /// If the task is scheduled in the future,
        /// sleep exactly until that time.
        ///
        if (scheduledTelemetryTask.nextDueTimeMilliseconds > nowMilliseconds) {
          final int waitMilliseconds = scheduledTelemetryTask.nextDueTimeMilliseconds - nowMilliseconds;
          await Future.delayed(Duration(milliseconds: waitMilliseconds));
          continue;
        }

        /// Token Availability Check
        ///
        /// If no token is available, briefly yield to avoid CPU spinning.
        ///
        if (tokens < 1.0) {
          await Future.delayed(const Duration(milliseconds: 2));
          continue;
        }

        // Remove task before executing to maintain heap integrity.
        heap.removeFirst();
        tokens -= 1.0;

        // Capture query start timestamp.
        final int queryStartMilliseconds = nowMilliseconds;

        // Declare queryEndMilliseconds outside try block
        // so it remains in scope for adaptive scheduling.
        int queryEndMilliseconds = queryStartMilliseconds;

        try {
          final DetailedPID detailedPID = scheduledTelemetryTask.detailedPID;
          final dynamic value = await _adapter.queryPID(detailedPID);

          queryEndMilliseconds = DateTime.now().millisecondsSinceEpoch;

          final int latencyMilliseconds = queryEndMilliseconds - queryStartMilliseconds;

          /// EMA Update
          ///
          /// newAverage =
          ///     oldAverage * retentionFactor +
          ///     latency * smoothingFactor
          ///
          averageLatencyMilliseconds =
              (averageLatencyMilliseconds * latencyRetentionFactor) +
                  (latencyMilliseconds * latencySmoothingFactor);

          onData(TelemetryData({detailedPID: value}));

        } catch (_) {
          // Failures are isolated to individual PIDs.
          // Scheduler stability is preserved.

          // Even on failure, update end time to prevent
          // artificial compression of scheduling.
          queryEndMilliseconds = DateTime.now().millisecondsSinceEpoch;
        }

        /// Adaptive Spacing
        ///
        /// Clamp latency-derived spacing to safe bounds.
        ///
        /// 5ms minimum:
        ///     Prevents ultra-tight loops.
        ///
        /// 200ms maximum:
        ///     Prevents runaway slowdown.
        ///
        final int adaptiveSpacingMilliseconds = averageLatencyMilliseconds.clamp(5, 200).toInt();

        scheduledTelemetryTask.nextDueTimeMilliseconds =
            queryEndMilliseconds +
                scheduledTelemetryTask.intervalMilliseconds +
                adaptiveSpacingMilliseconds;

        heap.add(scheduledTelemetryTask);
      }
    }

    schedulerLoop();

    return TelemetrySession(() {
      isRunning = false;
    });
  }

  /// Maps raw PID strings to their corresponding [DetailedPID] objects.
  ///
  /// This utility method converts simple hexadecimal PID strings
  /// into full metadata objects required by:
  ///
  /// - [stream]
  /// - [query]
  /// - Any typed telemetry access
  ///
  /// Example:
  /// ```
  /// ["010C", "010D"]
  /// →
  /// [engineRevolutionsPerMinute, vehicleSpeed]
  /// ```
  ///
  /// Matching Behavior:
  ///
  /// - Performs exact string matching against `parameterID`
  /// - Ignores unknown or unsupported PIDs silently
  /// - Preserves order of input list when matches are found
  ///
  /// ⚠️ Important:
  /// - Duplicate PID strings in the input list will produce duplicate
  ///   entries in the output list.
  /// - Invalid or unsupported PIDs are ignored.
  ///
  /// ### Parameters:
  /// - (`List<String>` pIDList):
  ///     List of hexadecimal PID strings (e.g., "010C").
  ///
  /// ### Returns:
  /// - (`List<DetailedPID>`)
  ///     List of matching PID metadata objects.
  ///
  /// ### Complexity:
  /// - Time Complexity: O(N × M)
  ///   Where:
  ///   - N = number of input PIDs
  ///   - M = number of defined PIDs in [allDetailedPIDs]
  ///
  /// ### Usage:
  /// ```dart
  /// final detailedPIDs = telemetry.getDetailedPIDsFromPIDList([
  ///   "010C",
  ///   "010D"
  /// ]);
  /// ```
  List<DetailedPID> getDetailedPIDsFromPIDList(List<String> pIDList) {
    final List<DetailedPID> detailed = [];

    for (final parameterID in pIDList) {
      final match = allDetailedPIDs
          .where((detailedPID) => detailedPID.parameterID == parameterID)
          .toList();

      if (match.isNotEmpty) {
        detailed.add(match.first);
      }
    }

    return detailed;
  }

  /// Executes a one-time sequential telemetry query.
  ///
  /// This method performs a single-pass query over the provided
  /// list of [DetailedPID] definitions.
  ///
  /// Unlike [stream], this method:
  ///
  /// - Does NOT schedule repeated polling
  /// - Does NOT apply rate limiting
  /// - Does NOT use adaptive latency control
  /// - Executes sequentially in the provided order
  ///
  /// Execution Model:
  ///
  /// 1. Verifies adapter connectivity
  /// 2. Iterates over each PID in order
  /// 3. Awaits each `_adapter.queryPID()` call
  /// 4. Stores result in a map
  /// 5. Returns aggregated results
  ///
  /// ⚠️ Error Behavior:
  ///
  /// - Errors are NOT swallowed.
  /// - Any exception thrown by `_adapter.queryPID`
  ///   propagates to the caller.
  /// - This ensures transparency and predictable failure handling.
  ///
  /// ### Parameters:
  /// - (`List<DetailedPID>` detailedPIDs):
  ///     List of PIDs to query.
  ///
  /// ### Returns:
  /// - (`Future<Map<DetailedPID, dynamic>>`)
  ///     A map containing:
  ///     - Key → PID metadata object
  ///     - Value → Decoded ECU response
  ///
  /// ### Throws:
  /// - (`StateError`)
  ///     If the adapter is not connected.
  ///
  /// - (Any adapter exception)
  ///     Propagated directly from `_adapter.queryPID`.
  ///
  /// ### Performance Characteristics:
  /// - Sequential execution (not parallel)
  /// - Total execution time ≈ sum of individual query latencies
  /// - Recommended for:
  ///     - Configuration reads
  ///     - On-demand diagnostics
  ///     - Single-shot data capture
  ///
  /// ### Usage:
  /// ```dart
  /// final results = await telemetry.query(
  ///   detailedPIDs: [
  ///     telemetry.engineRevolutionsPerMinute,
  ///     telemetry.vehicleSpeed
  ///   ],
  /// );
  ///
  /// final double? rpm = results[telemetry.engineRevolutionsPerMinute];
  /// ```
  Future<Map<DetailedPID, dynamic>> query({required List<DetailedPID> detailedPIDs}) async {
    if (!_adapter.isConnected) {
      throw StateError('Adapter is not connected.');
    }

    final Map<DetailedPID, dynamic> results = {};

    for (final DetailedPID parameterID in detailedPIDs) {
      // We allow errors to propagate naturally to the caller
      final dynamic value = await _adapter.queryPID(parameterID);
      results[parameterID] = value;
    }

    return results;
  }
}

