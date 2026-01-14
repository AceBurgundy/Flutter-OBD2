import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:obd2/src/functions.dart';

/// A helper class to manage Bluetooth Low Energy (BLE) lifecycle and
/// connectivity specifically for OBD2 adapters.
///
/// This class handles state checks, device retrieval, and connection management
/// using the Flutter Blue Plus library.
class OBD2BluetoothService {

  /// The characteristic used to send data to the OBD2 adapter.
  BluetoothCharacteristic? _writeCharacteristic;

  /// The current connected device instance.
  BluetoothDevice? _connectedDevice;

  /// Initializes the Bluetooth state and ensures FBP is ready.
  ///
  /// ### Returns:
  /// - (`Future<void>`): A future that completes when initialization is complete.
  ///
  /// ### Usage:
  /// ```dart
  /// await BluetoothService.initialize();
  /// ```
  static Future<void> initialize() async {
    // FBP automatically initializes, but we can check state here
    await FlutterBluePlus.adapterState.first;
  }

  /// Checks if Bluetooth is currently powered on and available.
  ///
  /// ### Returns:
  /// - (`Future<bool>`): A boolean value indicating if Bluetooth is active.
  ///
  /// ### Usage:
  /// ```dart
  /// bool active = await BluetoothService.isActive;
  /// ```
  static Future<bool> get isActive async {
    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  /// Retrieves a list of devices already bonded/paired with the system.
  ///
  /// ### Returns:
  /// - (`Future<List<BluetoothDevice>>`): A list of bonded devices.
  ///
  /// ### Usage:
  /// ```dart
  /// List<BluetoothDevice> devices = await BluetoothService.pairedDevices;
  /// ```
  static Future<List<BluetoothDevice>> get pairedDevices async {
    // In BLE, we look for "Bonded" devices on Android and "System" devices on iOS
    return await FlutterBluePlus.bondedDevices;
  }

  /// Establishes a GATT connection to a specific BLE device
  /// and discovers its UART services for communication.
  ///
  /// ### Arguments:
  /// - (`BluetoothDevice device`) - The target OBD2 scanner.
  ///
  /// ### Returns:
  /// - (`Future<BluetoothDevice?>`) - Returns the device if connected, else null.
  ///
  /// ### Usage:
  /// ```dart
  /// var device = await service.connect(selectedDevice);
  /// ```
  Future<BluetoothDevice?> connect(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false, license: License.free);
      _connectedDevice = device;

      // Discover services to find the communication pipe (UART)
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Look for a characteristic that supports writing
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic = characteristic;
          }
        }
      }
      return _connectedDevice;
    } catch (error) {
      print("Connection Error: - $error");
      return null;
    }
  }

  /// Terminates the active connection with the OBD2 scanner.
  ///
  /// ### Returns:
  /// - (`Future<bool>`): True if disconnected successfully.
  ///
  /// ### Usage:
  /// ```dart
  /// await service.disconnect();
  /// ```
  Future<bool> disconnect() async {
    if (_connectedDevice == null) return false;

    await _connectedDevice!.disconnect();
    _connectedDevice = null;
    _writeCharacteristic = null;
    return true;
  }

  /// Getter to check if the app is currently linked to a device.
  ///
  /// ### Returns:
  /// - (`bool`): A boolean value indicating the connection status.
  ///
  /// ### Usage:
  /// ```dart
  /// if (service.isConnected) { ... }
  /// ```
  bool get isConnected => _connectedDevice != null;

  /// Internal Helper:
  /// - Returns the write characteristic for the OBD2 class to use.
  BluetoothCharacteristic? get writeCharacteristic => _writeCharacteristic;
}