import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:obd2/obd2.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: OBD2DemoPage(),
    );
  }
}

class OBD2DemoPage extends StatefulWidget {
  const OBD2DemoPage({super.key});

  @override
  State<OBD2DemoPage> createState() => _OBD2DemoPageState();
}

class _OBD2DemoPageState extends State<OBD2DemoPage> {
  BluetoothAdapterOBD2? scanner;
  TelemetrySession? telemetrySession;

  final SaeJ1979 saeJ1979Standard = SaeJ1979();

  BluetoothDevice? connectedDevice;
  bool isStreaming = false;

  double? retrievedRPM;

  @override
  void initState() {
    super.initState();
    _ensureBluetoothReady();
  }

  Future<void> _ensureBluetoothReady() async {
    await FlutterBluePlus.adapterState.first;
  }

  /// Opens a dialog listing paired Bluetooth devices
  Future<void> _showPairedDevicesDialog() async {
    final List<BluetoothDevice> devices =
    await FlutterBluePlus.bondedDevices;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Paired Devices'),
          content: SizedBox(
            width: double.maxFinite,
            child: devices.isEmpty
                ? const Text('No paired devices found.')
                : ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(
                    device.platformName.isNotEmpty
                        ? device.platformName
                        : device.remoteId.toString(),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _connectToDevice(device);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Connects to the selected Bluetooth device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      retrievedRPM = null;
      isStreaming = false;
    });

    scanner?.disconnect();
    telemetrySession?.stop();

    scanner = BluetoothAdapterOBD2(
      diagnosticStandard: saeJ1979Standard,
    );

    await scanner!.connect(device);

    setState(() {
      connectedDevice = device;
    });
  }

  /// Starts live telemetry streaming
  void _startLiveStream() {
    if (scanner == null || !scanner!.isConnected) return;
    DetailedPID rpm = saeJ1979Standard.detailedPIDs.rpm;

    telemetrySession = scanner!.stream(
      detailedPIDs: [rpm],
      onData: (data) {
        final rpmReading = data[rpm];
        if (rpmReading == null) return;

        setState(() {
          retrievedRPM = rpmReading;
          isStreaming = true;
        });
      },
    );
  }

  @override
  void dispose() {
    telemetrySession?.stop();
    scanner?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = scanner?.isConnected == true;

    return Scaffold(
      appBar: AppBar(title: const Text('OBD-II Demo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// Connection status
            Text(
              isConnected
                  ? 'Connected to: ${connectedDevice?.platformName ?? connectedDevice?.remoteId}'
                  : 'Not connected',
              style: TextStyle(
                fontSize: 16,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),

            const SizedBox(height: 24),

            /// Paired devices button
            ElevatedButton(
              onPressed: _showPairedDevicesDialog,
              child: const Text('PAIRED DEVICES'),
            ),

            const SizedBox(height: 16),

            /// Live stream button
            ElevatedButton(
              onPressed: isConnected ? _startLiveStream : null,
              child: const Text('LIVE STREAM'),
            ),

            const SizedBox(height: 32),

            /// RPM display
            Text(
              retrievedRPM == null
                  ? 'RPM: --'
                  : 'RPM: ${retrievedRPM!.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
