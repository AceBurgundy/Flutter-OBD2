// bluetooth_helper.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'functions.dart';
import 'permission_manager.dart';
import 'telemetry_provider.dart';

class BluetoothHelper {

  static Future<void> handleShowDevices(BuildContext context, TelemetryProvider provider) async {
    try {
      // Check if Bluetooth is supported on the device
      if (await FlutterBluePlus.isSupported == false) {
        if (!context.mounted) return;
        snackBar(context, 'Bluetooth is not supported on this device');
        return;
      }

      // Checking the current Bluetooth state
      final BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;

      if (state == BluetoothAdapterState.off) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
          } catch (e) {
            if (!context.mounted) return;
            snackBar(context, 'Please turn on Bluetooth manually');
          }
        } else {
          if (!context.mounted) return;
          snackBar(context, 'Please turn on Bluetooth manually');
        }
        return;
      }

      if (state == BluetoothAdapterState.unauthorized) {
        if (!context.mounted) return;
        snackBar(context, 'Bluetooth permissions missing. Please check your settings');
        return;
      }

      if (state != BluetoothAdapterState.on) {
        if (!context.mounted) return;
        snackBar(context, 'Bluetooth status: ${state.name}. Please wait or check settings');
        return;
      }

      // Permissions and device fetching
      final bool hasPermission = await PermissionManager.requestHardwarePermissions();
      if (!hasPermission) {
        if (!context.mounted) return;
        snackBar(context, 'Hardware permissions denied');
        return;
      }

      final List<BluetoothDevice> pairedDevices = await FlutterBluePlus.bondedDevices;

      if (!context.mounted) return;

      if (pairedDevices.isEmpty) {
        snackBar(context, 'No paired devices found. Please pair a device in settings first');
        return;
      }

      // Show the selection dialog
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Select OBD-II Adapter'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pairedDevices.length,
              itemBuilder: (context, index) {
                final device = pairedDevices[index];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(device.platformName.isNotEmpty ? device.platformName : "Unknown Device"),
                  onTap: () {
                    provider.connectToDevice(device);
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
        message: 'Failed to retrieve paired Bluetooth devices',
      );

      if (context.mounted) {
        snackBar(context, 'An error occurred while fetching Bluetooth devices');
      }
    }
  }
}