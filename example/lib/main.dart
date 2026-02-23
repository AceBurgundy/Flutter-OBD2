import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/bluetooth_helper.dart';
import 'core/functions.dart';
import 'core/telemetry_provider.dart';

final GlobalKey<ScaffoldMessengerState> snackBarKey = GlobalKey<ScaffoldMessengerState>();
const Color background = Color(0xFF131313);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

  runApp(
    ChangeNotifierProvider(
      create: (context) => TelemetryProvider()..initializeProvider(),
      child: const SampleApp(),
    ),
  );
}

class SampleApp extends StatelessWidget {
  const SampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: "American Captain Patrius",
      ),
      home: const DashboardPage(),
    );
  }
}

enum ValueType { percent, temperature }

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // Fixed widths for the columns
  static const double columnWidth = 170.0;
  static const double spacingHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TelemetryProvider>();

    Widget telemetryItem(String label, double? value, { ValueType? type }) {
      final displayValue = (value ?? 0).toStringAsFixed(0);
      String finalType = "";

      if (type != null) {
        switch (type) {
          case ValueType.temperature:
            finalType = "°C";
            break;
          case ValueType.percent:
            finalType = "%";
            break;
        }
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 75,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 3),
              Text(
                finalType,
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
            ],
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );
    }

    final bool isBluetoothConnected = provider.scanner?.isConnected == true;

    String statusMessage;

    if (provider.isStreaming) {
      statusMessage = "Stream Started";
    } else if (isBluetoothConnected) {
      statusMessage = "Bluetooth Connected";
    } else {
      statusMessage = "Bluetooth Disconnected";
    }

    /// Toggles the telemetry data stream on or off.
    ///
    /// Handles error logging and user notification via snackbars if the
    /// connection or stream fails.
    ///
    /// ### Usage:
    /// ```dart
    /// toggleStream();
    /// ```
    void toggleStream() {
      if (provider.isStreaming) {
        try {
          provider.stopTelemetryStream();
          snackBar(context, "Live Stream Stopped!");
        } catch (error, stack) {
          logError(error, stack, message: "Error when stopping stream");
          snackBar(context, "Stream break error");
        }
        return;
      }

      try {
        if (provider.scanner == null) {
          snackBar(context, "Scanner is missing. Connect to one");
          return;
        }
        provider.startTelemetryStream();
        snackBar(context, "Live stream started!");
      } catch (error, stack) {
        logError(error, stack, message: 'Failed to start live data streaming');
        snackBar(context, "Live stream failed! Something went wrong");
        provider.stopTelemetryStream();
      }
    }

    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          const Spacer(flex: 1),
          Expanded(
            flex: 7,
            child: Center(
              child: Table(
                // This defines the strict width of your grid
                defaultColumnWidth: const FixedColumnWidth(columnWidth),
                children: [
                  TableRow(
                    children: [
                      telemetryItem("Speed (KPH)", provider.vehicleSpeed),
                      telemetryItem("RPM", provider.engineRpm),
                      telemetryItem("Coolant", provider.coolantTemperature, type: ValueType.temperature),
                    ],
                  ),
                  // Spacer Row
                  const TableRow(
                    children: [
                      SizedBox(height: spacingHeight),
                      SizedBox(height: spacingHeight),
                      SizedBox(height: spacingHeight),
                    ],
                  ),
                  TableRow(
                    children: [
                      telemetryItem("Throttle", provider.throttlePosition, type: ValueType.percent),
                      telemetryItem("Load", provider.engineLoad, type: ValueType.percent),
                      telemetryItem("Timing", provider.timingAdvance, type: ValueType.percent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Bottom Bar
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              color: Colors.white.withValues(alpha: 0.03),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: isBluetoothConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    statusMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1),
                  ),
                  const Spacer(),
                  _ControlButton(
                    icon: Icons.bluetooth,
                    color: isBluetoothConnected ? Colors.blue : Colors.grey[800]!,
                    onPressed: () => BluetoothHelper.handleShowDevices(context, provider),
                  ),
                  const SizedBox(width: 15),
                  _ControlButton(
                    icon: provider.isStreaming ? Icons.stop : Icons.play_arrow,
                    color: provider.isStreaming ? Colors.redAccent : Colors.green,
                    onPressed: () => toggleStream(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ControlButton({required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}