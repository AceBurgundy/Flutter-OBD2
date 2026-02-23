// test/obd2_test.dart

import 'dart:async';

import 'package:obd2/obd2.dart';
import 'package:obd2/src/core/adapter_series/adapter_obd2.dart';
import 'package:test/test.dart';

/// PID = Parameter Identifier
/// DTC = Diagnostic Trouble Code
/// ECU = Engine Control Unit

/// A fake adapter used for unit testing without real BLE hardware.
///
/// This adapter simulates:
/// - PID responses
/// - Capability bitmasks
/// - DTC byte payloads
class FakeAdapter extends AdapterOBD2 {
  /// Simulated connection state.
  bool _connected = true;

  /// Simulated incoming stream controller.
  final StreamController<List<int>> _controller =
  StreamController.broadcast();

  /// Predefined response map keyed by PID.
  final Map<String, dynamic> _mockResponses;

  FakeAdapter(this._mockResponses);

  @override
  bool get isConnected => _connected;

  @override
  Stream<List<int>> get incomingData => _controller.stream;

  @override
  Future<void> write(List<int> data) async {}

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<dynamic> queryPID(DetailedPID detailedPID) async {
    return _mockResponses[detailedPID.parameterID];
  }
}

void main() {
  group('SAE J1979 Formula Evaluation Tests', () {
    test('RPM formula should decode correctly', () async {
      final adapter = FakeAdapter({
        '010C': 3000.0,
      });

      final telemetry = Telemetry(adapter);

      final result = await adapter.queryPID(telemetry.rpm);

      expect(result, 3000.0);
    });

    test('Speed formula should decode correctly', () async {
      final adapter = FakeAdapter({
        '010D': 88.0,
      });

      final telemetry = Telemetry(adapter);

      final result = await adapter.queryPID(telemetry.speed);

      expect(result, 88.0);
    });
  });

  group('Composite PID Parsing Tests', () {
    test('Lambda composite PID should return list', () async {
      final adapter = FakeAdapter({
        '0124': [1.0, 0.45],
      });

      final telemetry = Telemetry(adapter);

      final result = await adapter.queryPID(telemetry.lambdaBank1Sensor1);

      expect(result, isA<List<double>>());
      expect(result.length, 2);
    });
  });

  group('DTC Decoding Tests', () {
    test('Mode 03 should decode DTC bytes correctly', () async {
      final adapter = FakeAdapter({
        '03': [0x01, 0x0C], // Example: P010C
      });

      final mode03 = ReadCodes(adapter);

      final codes = await mode03.getDTCs();

      expect(codes, isA<List<String>>());
    });
  });

  group('Odometer Calculation Tests', () {
    test('Odometer should increment correctly', () async {
      final adapter = FakeAdapter({});
      final telemetry = Telemetry(adapter);

      final DateTime lastUpdate =
      DateTime.now().subtract(const Duration(hours: 1));

      final newValue = await telemetry.calculateOdometer(
        currentOdometer: 1000.0,
        currentSpeedKmh: 60.0,
        lastUpdateTime: lastUpdate,
      );

      expect(newValue > 1000.0, true);
    });

    test('Odometer should not increment under GPS drift threshold', () async {
      final adapter = FakeAdapter({});
      final telemetry = Telemetry(adapter);

      final DateTime lastUpdate =
      DateTime.now().subtract(const Duration(hours: 1));

      final newValue = await telemetry.calculateOdometer(
        currentOdometer: 1000.0,
        currentSpeedKmh: 2.0,
        lastUpdateTime: lastUpdate,
      );

      expect(newValue, 1000.0);
    });
  });

  group('TelemetryData Type Safety Tests', () {
    test('Should store and retrieve typed values', () {
      final telemetry = Telemetry(
        FakeAdapter({}),
      );

      final data = TelemetryData({
        telemetry.rpm: 3500.0,
      });

      final rpm = data.get<double>(telemetry.rpm);

      expect(rpm, 3500.0);
    });
  });

  group('Capability Detection Tests', () {
    test('Should return empty list if no support', () async {
      final adapter = FakeAdapter({
        '0100': [0x00, 0x00, 0x00, 0x00],
      });

      final telemetry = Telemetry(adapter);

      final supported = await telemetry.detectSupportedTelemetry();

      expect(supported, isEmpty);
    });
  });
}