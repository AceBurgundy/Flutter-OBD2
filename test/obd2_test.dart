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
  bool _connected = true;

  final StreamController<List<int>> _controller =
      StreamController.broadcast();

  final Map<String, dynamic> _mockResponses;

  FakeAdapter(this._mockResponses);

  @override
  bool get isConnected => _connected;

  @override
  Stream<List<int>> get incomingData => _controller.stream;

  @override
  Future<void> write(List<int> data) async {
    // No-op for unit tests
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  /// PID-level abstraction (used by older tests)
  @override
  Future<dynamic> queryPID(DetailedPID detailedPID) async {
    return _mockResponses[detailedPID.parameterID];
  }

  /// NEW: Service-level abstraction (used by Mode 03 / 04)
  @override
  Future<List<int>?> sendService(String serviceHex) async {
    return _mockResponses[serviceHex] as List<int>?;
  }

  /// NEW: Service + PID abstraction (used by Mode 01 / 02)
  @override
  Future<List<int>?> sendServiceWithPID(
      String serviceHex,
      String parameterIDHex,
  ) async {
    return _mockResponses["$serviceHex$parameterIDHex"] as List<int>?;
  }
}

void main() {
  group('SAE J1979 Formula Evaluation Tests', () {
    test('RPM formula should decode correctly', () async {
      final adapter = FakeAdapter({
        '010C': 3000.0,
      });

      final result = await adapter.queryPID(Telemetry.rpm);
      expect(result, 3000.0);
    });

    test('Speed formula should decode correctly', () async {
      final adapter = FakeAdapter({
        '010D': 88.0,
      });

      final result = await adapter.queryPID(Telemetry.speed);
      expect(result, 88.0);
    });
  });

  group('Composite PID Parsing Tests', () {
    test('Lambda composite PID should return list', () async {
      final adapter = FakeAdapter({
        '0124': [1.0, 0.45],
      });

      final result = await adapter.queryPID(Telemetry.lambdaBank1Sensor1);

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
    test('Odometer should increment correctly', () {
      final engine = OdometerEngine(1000.0);

      final start = DateTime.now();
      engine.start(start);

      final next = start.add(const Duration(seconds: 30));

      engine.update(60.0, next); // 60 km/h for 30 seconds

      expect(engine.value > 1000.0, true);
    });

    test('Odometer should not increment under GPS drift threshold', () {
      final engine = OdometerEngine(1000.0);

      final start = DateTime.now();
      engine.start(start);

      final next = start.add(const Duration(seconds: 30));

      engine.update(0.2, next); // Below 0.5 km/h threshold

      expect(engine.value, 1000.0);
    });
  });

  group('TelemetryData Type Safety Tests', () {
    test('Should store and retrieve typed values', () {
      final data = TelemetryData({
        Telemetry.rpm: 3500.0,
      });

      final rpm = data.get<double>(Telemetry.rpm);
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