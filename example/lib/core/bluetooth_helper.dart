import 'dart:async';
import 'dart:io';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'functions.dart';
import 'permission_manager.dart';
import 'telemetry_provider.dart';

class BluetoothHelper {
  static Future<void> handleShowDevices(
      BuildContext context, TelemetryProvider provider) async {
    try {
      // 1️⃣ Check BLE support
      final bool isSupported = await UniversalBle.isSupported;

      if (!isSupported) {
        if (!context.mounted) return;
        snackBar(context, 'Bluetooth is not supported on this device');
        return;
      }

      // 2️⃣ Check Bluetooth state
      final availability = await UniversalBle.getBluetoothAvailabilityState();

      if (availability != BleAvailabilityState.poweredOn) {
        if (!context.mounted) return;
        snackBar(context, 'Please turn on Bluetooth');
        return;
      }

      // 3️⃣ Request permissions
      final bool hasPermission =
          await PermissionManager.requestHardwarePermissions();

      if (!hasPermission) {
        if (!context.mounted) return;
        snackBar(context, 'Hardware permissions denied');
        return;
      }

      // 4️⃣ Start scanning instead of bondedDevices
      final List<DiscoveredDevice> discoveredDevices = [];
      final StreamSubscription scanSub =
          UniversalBle.scanStream.listen((device) {
        if (!discoveredDevices
            .any((d) => d.deviceId == device.deviceId)) {
          discoveredDevices.add(device);
        }
      });

      await UniversalBle.startScan();

      // Scan for 4 seconds
      await Future.delayed(const Duration(seconds: 4));
      await UniversalBle.stopScan();
      await scanSub.cancel();

      if (!context.mounted) return;

      if (discoveredDevices.isEmpty) {
        snackBar(context, 'No BLE devices found nearby');
        return;
      }

      // 5️⃣ Show selection dialog
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(
            'Select OBD-II Adapter',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: background,
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = discoveredDevices[index];

                return ListTile(
                  leading:
                      const Icon(Icons.bluetooth, color: Colors.white),
                  title: Text(
                    device.name?.isNotEmpty == true
                        ? device.name!
                        : "Unknown Device",
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    device.deviceId,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () {
                    provider.connectToDevice(device.deviceId);
                    Navigator.pop(dialogContext);
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (error, stack) {
      logError(
        error,
        stack,
        message: 'Failed to retrieve Bluetooth devices',
      );

      if (context.mounted) {
        snackBar(
            context, 'An error occurred while fetching Bluetooth devices');
      }
    }
  }
}