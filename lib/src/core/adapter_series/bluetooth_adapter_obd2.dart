import 'dart:async';
import 'package:universal_ble/universal_ble.dart';
import 'adapter_obd2.dart';

class BluetoothAdapterOBD2 extends AdapterOBD2 {
  String? _connectedDeviceId;
  BleCharacteristic? _writeCharacteristic;

  final StreamController<List<int>> _incomingDataController =
      StreamController.broadcast();

  final List<StreamSubscription> _notificationSubscriptions = [];

  StreamSubscription<BleConnectionState>? _connectionStateSubscription;

  BluetoothAdapterOBD2();

  @override
  bool get isConnected => _connectedDeviceId != null;

  @override
  Stream<List<int>> get incomingData => _incomingDataController.stream;

  /// Connect using deviceId instead of BluetoothDevice
  Future<void> connect(String deviceId) async {
    try {
      // 1️⃣ Connect
      await UniversalBle.connect(deviceId);
      _connectedDeviceId = deviceId;

      // 2️⃣ Listen for disconnect
      _connectionStateSubscription =
          UniversalBle.connectionStream.listen((event) {
        if (event.deviceId == deviceId &&
            event.connectionState == BleConnectionState.disconnected) {
          disconnect();
        }
      });

      // 3️⃣ Discover Services
      final services = await UniversalBle.discoverServices(deviceId);

      // 4️⃣ Greedy Discovery Loop
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          final uuid = characteristic.uuid.toLowerCase();

          // A. Identify write characteristic
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic ??= characteristic;

            if (uuid.contains("fff2") || uuid.contains("ffe1")) {
              _writeCharacteristic = characteristic;
            }
          }

          // B. Subscribe to notifications
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            await UniversalBle.setNotifiable(
              deviceId,
              service.uuid,
              characteristic.uuid,
              true,
            );

            final sub = UniversalBle.onValueChanged.listen((event) {
              if (event.deviceId == deviceId &&
                  event.characteristicUuid == characteristic.uuid) {
                if (!_incomingDataController.isClosed) {
                  _incomingDataController.add(event.value);
                }
              }
            });

            _notificationSubscriptions.add(sub);
          }
        }
      }

      if (_writeCharacteristic == null) {
        throw StateError('No writable characteristic found.');
      }

      // 5️⃣ Initialize adapter (AT commands)
      await initializeAdapter();
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> write(List<int> data) async {
    if (_writeCharacteristic == null || _connectedDeviceId == null) {
      throw StateError('Bluetooth adapter is not connected.');
    }

    await UniversalBle.writeValue(
      _connectedDeviceId!,
      _writeCharacteristic!.serviceUuid,
      _writeCharacteristic!.uuid,
      data,
      withoutResponse:
          _writeCharacteristic!.properties.writeWithoutResponse,
    );
  }

  @override
  Future<void> disconnect() async {
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    for (final sub in _notificationSubscriptions) {
      await sub.cancel();
    }
    _notificationSubscriptions.clear();

    if (_connectedDeviceId != null) {
      await UniversalBle.disconnect(_connectedDeviceId!);
    }

    _connectedDeviceId = null;
    _writeCharacteristic = null;
  }
}