// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Import your core files and the new helper
import 'core/bluetooth_helper.dart';
import 'core/functions.dart';
import 'core/telemetry_provider.dart';

final GlobalKey<ScaffoldMessengerState> snackBarKey = GlobalKey<ScaffoldMessengerState>();
const Color background = Color(0xFF131313);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
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

    Widget buildTelemetryItem(String label, double? value, { ValueType type = ValueType.percent }) {
      final displayValue = (value ?? 0).toStringAsFixed(0);
      final unit = type == ValueType.temperature ? "°C" : "%";

      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 50,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
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

    toggleStream() {
      // Toggle between start or stop stream
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

        if (provider.scanner!.isConnected) {
          snackBar(context, "Scanner exist but is not connected");
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;

          return Column(
            children: [
              SizedBox(height: totalHeight * 0.10),
              SizedBox(
                height: totalHeight * 0.70,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        buildTelemetryItem("RPM", provider.engineRpm),
                        buildTelemetryItem("Speed", provider.vehicleSpeed),
                        buildTelemetryItem(
                          "Coolant Temperature",
                          provider.coolantTemperature,
                          type: ValueType.temperature,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        buildTelemetryItem(
                          "Throttle Position",
                          provider.throttlePosition,
                        ),
                        buildTelemetryItem("Engine Load", provider.engineLoad),
                        buildTelemetryItem(
                          "Timing Advance",
                          provider.timingAdvance,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: totalHeight * 0.20,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: isBluetoothConnected
                              ? Colors.blue
                              : Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          // Call your new helper class here!
                          onPressed: () => BluetoothHelper.handleShowDevices(
                            context,
                            provider,
                          ),
                          icon: const Icon(
                            Icons.bluetooth,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: provider.isStreaming
                              ? Colors.blue
                              : Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: () => toggleStream(),
                          icon: Icon(
                            provider.isStreaming
                                ? Icons.stop
                                : Icons.play_arrow,
                            color: Colors.white,
                          )
                        )
                      )
                    ]
                  )
                )
              ),
            ]
          );
        }
      )
    );
  }
}
