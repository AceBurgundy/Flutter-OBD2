import 'package:permission_handler/permission_handler.dart';

import 'functions.dart';

// BT: Bluetooth
// GPS: Global Positioning System

/// A utility class to manage hardware access rights for the application.
class PermissionManager {

  /// Requests runtime Bluetooth and Location permissions for Android devices.
  ///
  /// This method handles the necessary requirements for scanning for OBD2
  /// adapters and accessing GPS speed data.
  ///
  /// ### Returns:
  /// - (`Future<bool>`): True if all required permissions are granted by the user.
  ///
  /// ### Usage:
  /// ```dart
  /// final bool isReady = await PermissionManager.requestHardwarePermissions();
  /// if (isReady) {
  ///   DataStream.speedGPS(onData: (speed) => print(speed));
  /// }
  /// ```
  ///
  /// ### Throws:
  /// - (Exception): Logged via logError if the permission request process fails.
  static Future<bool> requestHardwarePermissions() async {
    try {
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      // Check if every requested permission in the map is currently granted
      return statuses.values.every((PermissionStatus status) => status.isGranted);
    } catch (error, stack) {
      logError(
        error,
        stack,
        message: 'Critical failure during hardware permission request sequence.',
      );
      return false;
    }
  }
}