import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:obd2/src/functions.dart';
import 'package:obd2/src/core/diagnostic_standards/standard_abstract.dart';
import '../adapter_obd2.dart';

/// BLE = Bluetooth Low Energy
/// GATT = Generic Attribute Profile
///
/// Adapter for Bluetooth OBD-II scanners that extends the OBD2 engine.
///
/// This class manages the physical Bluetooth connection, service discovery,
/// and the "Greedy" subscription model to ensure all data pipes are open.
class BluetoothAdapterOBD2 extends AdapterOBD2 {
  /// The currently connected Bluetooth device instance.
  BluetoothDevice? _connectedDevice;

  /// The GATT characteristic used to write commands to the adapter.
  BluetoothCharacteristic? _writeCharacteristic;

  /// Broadcasts incoming raw ASCII bytes to listeners.
  final StreamController<List<int>> _incomingDataController =
  StreamController.broadcast();

  /// A list of active subscriptions to BLE notifications.
  /// We keep track of multiple subscriptions because we listen to ALL
  /// notifying characteristics to ensure we don't miss the data pipe.
  final List<StreamSubscription<List<int>>> _notificationSubscriptions = [];

  /// Subscription to the physical device connection state.
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  /// Creates a Bluetooth OBD-II adapter instance.
  ///
  /// ### Parameters:
  /// - [standard] (DiagnosticStandard): The protocol standard (e.g., SAE J1979).
  BluetoothAdapterOBD2({required DiagnosticStandard standard})
      : super(standard: standard);

  /// Indicates whether the device is physically connected.
  @override
  bool get isConnected => _connectedDevice != null;

  /// Stream of raw ASCII bytes received from the adapter.
  @override
  Stream<List<int>> get incomingData => _incomingDataController.stream;

  /// Establishes a BLE connection and subscribes to all data pipes.
  ///
  /// This method uses a "Greedy" discovery strategy:
  /// 1. Connects to the device.
  /// 2. Scans for *all* characteristics.
  /// 3. Subscribes to *every* characteristic that supports Notify/Indicate.
  /// 4. Selects the best available characteristic for writing (preferring FFF2).
  ///
  /// ### Parameters:
  /// - [device] (BluetoothDevice): The target OBD-II adapter.
  ///
  /// ### Throws:
  /// - (StateError): If no writable characteristic is found.
  /// - (Exception): If connection fails.
  Future<void> connect(BluetoothDevice device) async {
    try {
      // 1. Connect
      // autoConnect: false ensures a direct, immediate connection attempt.
      await device.connect(autoConnect: false, license: License.free);
      _connectedDevice = device;

      // 2. Safety: Listen for disconnection
      // If the link drops, we must clean up immediately.
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          disconnect();
        }
      });

      // 3. Discover Services
      final List<BluetoothService> services = await device.discoverServices();

      // 4. Greedy Discovery Loop
      // We iterate over ALL services and characteristics.
      for (final BluetoothService service in services) {
        for (final BluetoothCharacteristic characteristic in service.characteristics) {
          final String uuid = characteristic.uuid.toString().toLowerCase();

          // A. Identify Write Characteristic
          // We prioritize standard OBD UUIDs (FFF2, FFE1) if found.
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            // If we haven't found a writer yet, take this one.
            _writeCharacteristic ??= characteristic;

            // If we found a "better" one (Standard ELM327 UUIDs), switch to it.
            if (uuid.contains("fff2") || uuid.contains("ffe1")) {
              _writeCharacteristic = characteristic;
            }
          }

          // B. Subscribe to Notifications (THE PIPE)
          // We subscribe to ANYTHING that supports Notify or Indicate.
          // This ensures we catch the data no matter which service the adapter uses.
          if (characteristic.properties.notify || characteristic.properties.indicate) {

            if (!characteristic.isNotifying) {
              await characteristic.setNotifyValue(true);
            }

            final StreamSubscription<List<int>> subscription =
            characteristic.lastValueStream.listen((List<int> data) {
              // Feed the data into the public stream.
              // The base AdapterOBD2 class is listening to this stream,
              // so it will automatically process the data.
              if (!_incomingDataController.isClosed) {
                _incomingDataController.add(data);
              }
            });

            _notificationSubscriptions.add(subscription);
          }
        }
      }

      if (_writeCharacteristic == null) {
        throw StateError('No writable characteristic found on this device.');
      }

      // 5. Initialize Adapter (AT commands)
      await initializeAdapter();

    } catch (error, stackTrace) {
      logError(error, stackTrace, message: 'Connection failed.');
      await disconnect();
      rethrow;
    }
  }

  /// Sends raw bytes to the adapter.
  ///
  /// This method checks the characteristic properties to determine
  /// if it should wait for a response (Write Request) or not (Write Command).
  ///
  /// ### Parameters:
  /// - [data] (List<int>): The ASCII bytes to send.
  @override
  Future<void> write(List<int> data) async {
    if (_writeCharacteristic == null || _connectedDevice == null) {
      throw StateError('Bluetooth adapter is not connected.');
    }

    try {
      // Use "Write Without Response" if the characteristic supports it.
      // This is significantly faster for OBD-II streaming.
      final bool canWriteNoResponse =
          _writeCharacteristic!.properties.writeWithoutResponse;

      await _writeCharacteristic!.write(
          data,
          withoutResponse: canWriteNoResponse
      );
    } catch (error, stackTrace) {
      logError(error, stackTrace, message: 'Write failed.');
      rethrow;
    }
  }

  /// Disconnects from the device and cleans up all listeners.
  @override
  Future<void> disconnect() async {
    try {
      // Cancel connection listener
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;

      // Cancel ALL notification subscriptions
      for (final StreamSubscription subscription in _notificationSubscriptions) {
        await subscription.cancel();
      }
      _notificationSubscriptions.clear();

      // Disconnect physical device
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      _connectedDevice = null;
      _writeCharacteristic = null;
    } catch (error, stackTrace) {
      logError(error, stackTrace, message: 'Disconnect failed.');
    }
  }
}