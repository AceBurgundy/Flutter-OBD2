import 'dart:async';
import 'dart:convert';

import 'package:math_expressions/math_expressions.dart';
import 'package:obd2/src/functions.dart';

import '../models.dart';
import 'diagnostic_standards/standard_abstract.dart';

/// AT = Attention Command (ELM327 adapter control commands)
/// ECU = Engine Control Unit
/// PID = Parameter Identifier (OBD-II telemetry code)
/// BLE = Bluetooth Low Energy

/// Defines the operational mode used when communicating with the ECU.
///
/// Each mode represents a standardized OBD-II request category.
enum OBDMode {
  /// Requests **real-time powertrain data** such as:
  /// - Engine RPM
  /// - Vehicle speed
  /// - Coolant temperature
  currentPowertrainData,

  /// Requests **static vehicle information** such as:
  /// - Vehicle Identification Number (VIN)
  /// - Calibration identifiers
  /// - ECU metadata
  vehicleInformation,
}

/// Represents an active telemetry streaming session.
///
/// A session controls:
/// - PID polling lifecycle
/// - ECU response parsing
/// - Emission of typed telemetry values
///
/// Sessions are disposable and must be stopped explicitly.
class TelemetrySession {
  /// Subscription to incoming adapter data.
  final StreamSubscription<List<int>> _incomingSubscription;

  /// Stops the telemetry session and releases all resources.
  void stop() {
    _incomingSubscription.cancel();
  }

  TelemetrySession(this._incomingSubscription);
}

/// Low-level communication interface and **OBD-II engine**.
///
/// This class represents a physical OBD-II scanner connected to a vehicle.
/// It contains:
/// - Transport abstraction (Bluetooth, USB, etc.)
/// - ECU command handling
/// - Telemetry parsing and evaluation logic
///
/// Child classes handle **how** bytes are transported.
/// This class handles **what** the bytes mean.
abstract class AdapterOBD2 {
  /// Indicates whether the adapter is currently connected
  /// and capable of sending or receiving data.
  bool get isConnected;

  /// Stream of raw ASCII bytes received from the adapter.
  Stream<List<int>> get incomingData;

  /// Writes raw ASCII-encoded bytes to the adapter.
  Future<void> write(List<int> data);

  /// Disconnects the adapter and releases all resources.
  Future<void> disconnect();

  /// Diagnostic standard used to build commands and parse ECU responses.
  final DiagnosticStandard diagnosticStandard;

  /// Cached parsed math expressions per PID for performance.
  final Map<String, Expression> _expressionCache = {};

  /// Indicates whether adapter initialization is in progress.
  bool _isInitializingAdapter = false;

  /// Last command sent to the ECU.
  String _latestCommand = '';

  /// Numeric identifier describing the last request type.
  int _requestCode = 0;

  AdapterOBD2({required this.diagnosticStandard});

  /// Initializes the diagnostic adapter using AT commands.
  ///
  /// This method is automatically called after a successful connection.
  ///
  /// ### Throws:
  /// - (`StateError`): If the adapter is not connected.
  /// - (`Exception`): If initialization fails.
  Future<void> initializeAdapter() async {
    if (!isConnected) {
      throw StateError('Adapter is not connected.');
    }

    _isInitializingAdapter = true;

    try {
      for (final String command
      in diagnosticStandard.initializationCommands) {
        await _sendCommand(command, requestCode: 100);
        await Future.delayed(const Duration(milliseconds: 150));
      }
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to initialize OBD-II adapter.',
      );
      rethrow;
    } finally {
      _isInitializingAdapter = false;
    }
  }

  /// Starts a telemetry streaming session.
  ///
  /// Only PIDs that are part of the current diagnostic standard
  /// (`diagnosticStandard.allowedDetailedPIDs`) are allowed. Passing
  /// a PID from another standard will throw an error.
  ///
  /// ### Parameters:
  /// - (`List<DetailedPID>`): PIDs to poll continuously.
  /// - (`void Function(Map<DetailedPID, double>)`):
  ///   Callback invoked when telemetry data is received.
  ///
  /// ### Returns:
  /// - (`TelemetrySession`): Active streaming session instance.
  TelemetrySession stream({
    required List<DetailedPID> detailedPIDs,
    required void Function(Map<DetailedPID, double>) onData,
  }) {
    if (!isConnected) {
      throw StateError('Adapter is not connected.');
    }

    if (detailedPIDs.isEmpty) {
      throw ArgumentError(
        'At least one PID must be provided to start a telemetry stream.',
      );
    }

    // Enforce standard ownership
    final allowed = diagnosticStandard.allowedDetailedPIDs;

    for (final pid in detailedPIDs) {
      if (!allowed.contains(pid)) {
        throw ArgumentError(
          'PID "${pid.name}" (${pid.parameterID}) does not belong to '
              'the "${diagnosticStandard.name}" diagnostic standard.',
        );
      }
    }

    final List<DetailedPID> telemetryQueue = List.of(detailedPIDs);
    String responseBuffer = '';

    final subscription = incomingData.listen((data) {
      responseBuffer += utf8.decode(data);

      if (!responseBuffer.contains('>')) return;

      final rawResponse = responseBuffer;
      responseBuffer = '';

      if (_isInitializingAdapter) return;

      final DetailedPID currentPID = telemetryQueue.removeAt(0);

      try {
        final value = _evaluatePIDResponse(currentPID, rawResponse);
        onData({currentPID: value});
      } catch (error, stackTrace) {
        logError(
          error,
          stackTrace,
          message: 'Failed to process telemetry for ${currentPID.name}',
        );
      } finally {
        telemetryQueue.add(currentPID);
        _requestNextPID(telemetryQueue.first);
      }
    });

    // Kick off first request
    _requestNextPID(telemetryQueue.first);

    return TelemetrySession(subscription);
  }

  /// Sends the next PID request to the ECU.
  void _requestNextPID(DetailedPID parameterID) {
    final String command =
    diagnosticStandard.buildDetailedPIDRequest(parameterID);

    _sendCommand(command, requestCode: 400);
  }

  /// Evaluates an ECU response into a typed telemetry value.
  double _evaluatePIDResponse(
      DetailedPID detailedPID,
      String rawResponse,
      ) {
    final String cleanedResponse = rawResponse
        .replaceAll(RegExp(r'[\n\r> ]'), '')
        .replaceAll('SEARCHING...', '');

    final List<String> bytes =
    diagnosticStandard.extractDataBytes(
      response: cleanedResponse,
      detailedPID: detailedPID,
    );

    String formula = detailedPID.formula;

    for (int index = 0; index < bytes.length; index++) {
      formula = formula.replaceAll(
        '[$index]',
        int.parse(bytes[index], radix: 16).toString(),
      );
    }

    final Expression expression = _expressionCache.putIfAbsent(
      detailedPID.parameterID,
          () => GrammarParser().parse(formula),
    );

    return RealEvaluator().evaluate(expression).toDouble();
  }

  /// Sends a raw command to the adapter.
  Future<void> _sendCommand(
      String command, {
        required int requestCode,
      }) async {
    if (!isConnected) {
      throw StateError('Adapter is not connected.');
    }

    try {
      _latestCommand = command;
      _requestCode = requestCode;

      await write(utf8.encode('$command\r\n'));
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to send command to OBD-II adapter.',
      );
      rethrow;
    }
  }
}
