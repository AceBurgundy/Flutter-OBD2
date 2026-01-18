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

  double? retrievedRPM;

  @override
  void initState() {
    super.initState();
    _startOBD2();
  }

  Future<void> _startOBD2() async {
    // Ensure Bluetooth is powered on
    await FlutterBluePlus.adapterState.first;

    // Fetch bonded (paired) devices
    final List<BluetoothDevice> devices =
    await FlutterBluePlus.bondedDevices;

    if (devices.isEmpty) {
      debugPrint('No paired OBD-II devices found.');
      return;
    }

    final BluetoothDevice device = devices.first;

    // Create Bluetooth OBD-II adapter
    scanner = BluetoothAdapterOBD2(
      diagnosticStandard: SaeJ1979Standard(),
    );

    // Connect + auto-initialize adapter
    await scanner!.connect(device);

    // Start telemetry streaming session
    telemetrySession = scanner!.stream(
      parameterIDs: [
        rpm, // From parameter_ids.dart
      ],
      onData: (data) {
        final telemetry = data[rpm];

        if (telemetry == null) return;

        setState(() {
          retrievedRPM = telemetry.value;
        });

        debugPrint('RPM: ${telemetry.value}');
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
    return Scaffold(
      appBar: AppBar(title: const Text('OBD-II RPM Test')),
      body: Center(
        child: Text(
          retrievedRPM == null
              ? 'Waiting for RPM data…'
              : 'RPM: ${retrievedRPM!.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
