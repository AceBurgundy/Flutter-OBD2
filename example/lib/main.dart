import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:obd2/obd2.dart';
import 'package:provider/provider.dart';
import 'core/functions.dart';
import 'core/permission_manager.dart';
import 'core/telemetry_provider.dart';

final GlobalKey<ScaffoldMessengerState> snackBarKey =
GlobalKey<ScaffoldMessengerState>();
const Color background = Color(0xFF131313);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
  ]);

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

Future<void> _handleShowDevices(
    BuildContext context, TelemetryProvider provider) async {
  try {
    final bool hasPermission = await PermissionManager.requestHardwarePermissions();
    if (!hasPermission) return;

    final List<BluetoothDevice> pairedDevices =
    await FlutterBluePlus.bondedDevices;

    if (!context.mounted) return;

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
                title: Text(
                  device.platformName.isNotEmpty
                      ? device.platformName
                      : device.remoteId.toString(),
                ),
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
    logError(error, stack, message: 'Failed to retrieve paired Bluetooth devices.');
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "$displayValue$unit",
              style: const TextStyle(
                fontSize: 52,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;

          return Column(
            children: [
              SizedBox(
                height: totalHeight * 0.45,
                child: Row(
                  children: [
                    buildTelemetryItem("RPM", provider.engineRpm),
                    buildTelemetryItem("Speed", provider.vehicleSpeed),
                    buildTelemetryItem(
                      "Coolant",
                      provider.coolantTemperature,
                      type: ValueType.temperature,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: totalHeight * 0.45,
                child: Row(
                  children: [
                    buildTelemetryItem("Throttle", provider.throttlePosition),
                    buildTelemetryItem("Engine Load", provider.engineLoad),
                    buildTelemetryItem("Timing", provider.timingAdvance),
                  ],
                ),
              ),
              SizedBox(
                height: totalHeight * 0.10,
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24),
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
                          borderRadius:
                          BorderRadius.circular(30),
                        ),
                        child: IconButton(
                          onPressed: () =>
                              _handleShowDevices(context, provider),
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
                          borderRadius:
                          BorderRadius.circular(30),
                        ),
                        child: IconButton(
                          onPressed: provider.isStreaming
                              ? provider.stopTelemetryStream
                              : provider.startTelemetryStream,
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
              )
            ]
          );
        }
      )
    );
  }
}
