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
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TelemetryProvider>();

    Widget telemetryItem(String label, double? value, {ValueType type = ValueType.percent}) {
      final displayValue = (value ?? 0).toStringAsFixed(0);
      final unit = type == ValueType.temperature ? "°C" : "%";

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayValue,
                style: const TextStyle(fontSize: 55, color: Colors.white, fontWeight: FontWeight.bold, height: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  unit,
                  style: const TextStyle(fontSize: 20, color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
        ],
      );
    }

    // REMOVED Expanded to allow items to sit closer together
    Widget itemsGroup(List<Widget> items) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: items,
    );

    final bool isBluetoothConnected = provider.scanner?.isConnected == true;
    String statusMessage = provider.isStreaming
        ? "STREAMING DATA"
        : (isBluetoothConnected ? "CONNECTED" : "DISCONNECTED");

    void toggleStream() {
      if (provider.isStreaming) {
        try {
          provider.stopTelemetryStream();
          snackBar(context, "Stream Stopped");
        } catch (error, stack) {
          logError(error, stack);
        }
      } else {
        if (provider.scanner == null) return;
        provider.startTelemetryStream();
      }
    }

    return Scaffold(
      backgroundColor: background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              const Spacer(flex: 1),

              Expanded(
                flex: 7,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      itemsGroup([
                        telemetryItem("RPM", provider.engineRpm),
                        const SizedBox(height: 40),
                        telemetryItem("Throttle", provider.throttlePosition),
                      ]),

                      const SizedBox(width: 150),

                      itemsGroup([
                        telemetryItem("Speed", provider.vehicleSpeed),
                        const SizedBox(height: 40),
                        telemetryItem("Load", provider.engineLoad),
                      ]),

                      const SizedBox(width: 150),

                      itemsGroup([
                        telemetryItem("Coolant", provider.coolantTemperature, type: ValueType.temperature),
                        const SizedBox(height: 40),
                        telemetryItem("Timing", provider.timingAdvance),
                      ]),
                    ],
                  ),
                ),
              ),

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
                        onPressed: toggleStream,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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