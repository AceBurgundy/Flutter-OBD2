import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:obd2/src/functions.dart';
import '../adapter_obd2.dart';

/// BLE = Bluetooth Low Energy
/// Adapter for Bluetooth OBD-II scanners that extends the OBD2 engine.
///
/// This class now implements [AdapterOBD2] and contains the OBD-II logic
/// for:
/// - Sending PID commands
/// - Streaming telemetry
/// - Parsing ECU responses
/// - Evaluating formulas
class BluetoothAdapterOBD2 extends AdapterOBD2 {
  /// Connected Bluetooth device instance.
  BluetoothDevice? _connectedDevice;

  /// GATT characteristic used to write commands to the adapter.
  BluetoothCharacteristic? _writeCharacteristic;

  /// Stream controller emitting incoming raw ASCII bytes.
  final StreamController<List<int>> _incomingDataController =
  StreamController.broadcast();

  /// Subscription to BLE notification updates.
  StreamSubscription<List<int>>? _notificationSubscription;

  /// Creates a Bluetooth OBD-II adapter instance.
  ///
  /// The adapter is not connected until [connect] is called.
  BluetoothAdapterOBD2({required super.diagnosticStandard});

  /// Indicates whether the Bluetooth adapter is connected.
  @override
  bool get isConnected => _connectedDevice != null;

  /// Stream of raw ASCII bytes received from the adapter.
  @override
  Stream<List<int>> get incomingData => _incomingDataController.stream;

  /// Establishes a BLE connection to a target OBD-II adapter
  /// and automatically initializes the diagnostic adapter.
  ///
  /// Discovers services, locates a writable characteristic,
  /// subscribes to notifications, and sends AT initialization commands.
  ///
  /// ### Parameters:
  /// - (`BluetoothDevice device`): Target OBD-II Bluetooth adapter.
  ///
  /// ### Throws:
  /// - (`StateError`): If no writable characteristic is found.
  /// - (`Exception`): If the connection or initialization fails.
  Future<void> connect(BluetoothDevice device) async {
    try {
      // Connect to device
      await device.connect(autoConnect: false, license: License.free);
      _connectedDevice = device;

      // Discover services
      final List<BluetoothService> services = await device.discoverServices();

      for (final BluetoothService service in services) {
        for (final BluetoothCharacteristic characteristic
        in service.characteristics) {
          // Identify writable characteristic
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic = characteristic;
          }

          // Subscribe to notifications
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            await characteristic.setNotifyValue(true);
            _notificationSubscription =
                characteristic.lastValueStream.listen((List<int> data) {
                  if (!_incomingDataController.isClosed) {
                    _incomingDataController.add(data);
                  }
                });
          }
        }
      }

      if (_writeCharacteristic == null) {
        throw StateError(
          'No writable Bluetooth characteristic found on OBD-II adapter.',
        );
      }

      // === Adapter auto-initialization ===
      initializeAdapter();
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to connect and initialize Bluetooth OBD-II adapter.',
      );
      rethrow;
    }
  }

  /// Sends raw ASCII bytes to the adapter.
  ///
  /// ### Parameters:
  /// - (`List<int>`): ASCII-encoded command bytes.
  ///
  /// ### Throws:
  /// - (`StateError`): If no device is connected.
  /// - (`Exception`): If the write operation fails.
  @override
  Future<void> write(List<int> data) async {
    if (_writeCharacteristic == null || _connectedDevice == null) {
      throw StateError('Bluetooth adapter is not connected.');
    }

    try {
      await _writeCharacteristic!.write(
        data,
        withoutResponse: _writeCharacteristic!.properties.writeWithoutResponse,
      );
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to write data to Bluetooth OBD-II adapter.',
      );
      rethrow;
    }
  }

  /// Disconnects from the Bluetooth adapter and releases resources.
  ///
  /// Cancels notifications, disconnects the device, and clears internal refs.
  @override
  Future<void> disconnect() async {
    try {
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      _connectedDevice = null;
      _writeCharacteristic = null;
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace,
        message: 'Failed to disconnect Bluetooth OBD-II adapter.',
      );
      rethrow;
    }
  }
}
