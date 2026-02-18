# 🚗 Flutter-OBD2

A **modern, diagnostic-standard–aware OBD-II SDK for Flutter**.

This package provides a robust, type-safe interface for communicating with **ELM327-compatible Bluetooth Low Energy (BLE)** adapters. It creates a clear separation between the **Transport Layer** (Bluetooth), the **Diagnostic Standard** (SAE J1979), and the **Service Modes** (Telemetry, DTCs, Freeze Frames).

## ⚠️ Testing Status

> **Current Stability:** > ✅ **Mode 01 (Live Telemetry):** Fully tested and production-ready.
> 🚧 **Modes 02, 03, & 04:** Implemented according to SAE J1979 specifications but **have not yet been fully validated on physical vehicles**. Please use these modes with caution and report any issues on the tracker. Further testing is planned for upcoming releases.

## ✨ Key Features

**🔌 Greedy BLE Connection:** Implements a "greedy" discovery strategy that subscribes to *all* notifying characteristics to ensure a connection, regardless of the specific service UUIDs used by cheap adapters.

**🏎️ SAE J1979 Standard:** Full support for the standard protocol used by most petrol/gasoline vehicles.

**📡 Smart Telemetry Streaming:** A recursive "wait-and-proceed" polling loop that respects the specific refresh rate (`bestPollingIntervalMs`) of each PID.

**🧬 Type-Safe PIDs:** Uses `DetailedPID<T>` to return `double`, `String`, or `List<double>` automatically—no manual casting required.

**🧮 Math Engine:** Integrated `math_expressions` parser to evaluate complex ECU formulas dynamically.

**📍 Odometer Estimation:** Built-in logic to calculate distance traveled using speed + time, with GPS drift filtering.

## 📦 Architecture

The SDK is built on a layered architecture to ensure extensibility.

1. 
**AdapterOBD2 (Abstract):** Handles the command queue, ASCII decoding, and formula evaluation.

2. 
**BluetoothAdapterOBD2 (Implementation):** Manages physical BLE connections using `flutter_blue_plus`.

3. 
**DiagnosticStandard (SAE J1979):** Defines how to format commands and parse bytes for a specific protocol.

4. 
**Service Modes:** Groups logic by function (e.g., `SAEJ1979ModeTelemetry`, `SAEJ1979ReadCodesMode`).

## 🚀 Getting Started

### 1. Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  obd2: ^1.0.0
  flutter_blue_plus: ^1.30.0 # Required for the Bluetooth Adapter

```

### 2. Initialization

Instantiate the standard and the adapter. The adapter handles the ELM327 initialization sequence (`AT Z`, `AT E0`, etc.) automatically upon connection.

```dart
import 'package:obd2/obd2.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// 1. Create the Standard (SAE J1979)
final SaeJ1979 standard = SaeJ1979();

// 2. Create the Adapter
final adapter = BluetoothAdapterOBD2(standard: standard);

// 3. Connect to a BLE Device
// The adapter will automatically negotiate the protocol
await adapter.connect(myBluetoothDevice);

```

### 3. Mode 01: Live Telemetry Streaming (Tested)

Use the `telemetry` property on the standard to stream data. The stream is intelligent: high-priority PIDs (like RPM) are polled faster than low-priority PIDs (like Fuel Level).

```dart
// Access Mode 01
final telemetry = standard.telemetry;

// Start Streaming
final session = telemetry.stream(
  adapter: adapter,
  detailedPIDs: [
    telemetry.rpm,                  // Updates fast (~10ms)
    telemetry.speed,
    telemetry.coolantTemperature,   // Updates slow (~5000ms)
  ],
  onData: (TelemetryData data) {
    // values are Type-Safe!
    if (data.hasData(telemetry.rpm)) {
      double rpm = data.get(telemetry.rpm)!; 
      print("RPM: $rpm");
    }
  },
);

// ... later
session.stop();

```

### 4. Experimental Modes (02, 03, 04)

The following modes are available for use but are currently pending extensive physical testing.

#### Mode 03 & 04: Diagnostic Trouble Codes (DTCs)

Read and clear "Check Engine" light codes.

```dart
// Mode 03: Read Codes
final mode03 = SAEJ1979ReadCodesMode();
final List<String> codes = await mode03.getDiagnosticTroubleCodes(adapter);

print("Faults found: $codes"); // e.g. ["P0300", "P0101"]

// Mode 04: Clear Codes (Resets MIL)
final mode04 = SAEJ1979ClearCodesMode();
bool success = await mode04.clearDiagnosticTroubleCodes(adapter);

```

#### Mode 02: Freeze Frames

Capture a snapshot of vehicle sensor data at the exact moment a trouble code was triggered.

```dart
final mode02 = SAEJ1979FreezeFrameMode();

final TelemetryData snapshot = await mode02.getFreezeFrameData(
  detailedPIDs: [mode02.rpm, mode02.coolantTemperature],
  adapter: adapter,
);

```

## 🧠 Advanced Features

### 🔍 Supported PID Discovery

Vehicles don't support every sensor. Use `detectSupportedTelemetry` to query the ECU's bitmask and find out exactly what is available.

```dart
List<String> supportedIds = await standard.detectSupportedTelemetry(
  adapter: adapter,
  validateAccessibility: true, // Actually queries each PID to confirm
);
print("Supported PIDs: $supportedIds"); // ["010C", "010D", ...]

```

### 📏 Odometer Calculation

Many vehicles do not expose the Odometer via standard OBD2. This package includes a utility to calculate distance based on speed over time, filtering out GPS drift when stationary.

```dart
double newOdometer = await standard.telemetry.calculateOdometer(
  currentOdometer: 50000.0,
  currentSpeedKmh: currentSpeed, // from GPS or OBD2
  lastUpdateTime: previousTimestamp,
);

```

## 📊 Supported PIDs (Mode 01)

The `SAEJ1979ModeTelemetry` class includes strongly-typed definitions for common PIDs:

| PID Name | Accessor | Return Type |
| --- | --- | --- |
| **Engine RPM** | `telemetry.rpm` | `double` |
| **Vehicle Speed** | `telemetry.speed` | `double` |
| **Coolant Temp** | `telemetry.coolantTemperature` | `double` |
| **Engine Load** | `telemetry.engineLoad` | `double` |
| **Fuel Level** | `telemetry.fuelLevel` | `double` |
| **Mass Air Flow** | `telemetry.massAirFlow` | `double` |
| **Odometer** | `telemetry.odometer` | `double` |
| **Lambda (O2)** | `telemetry.lambdaBank1Sensor1` | `List<double>` |
| **Fuel Type** | `telemetry.fuelType` | `String` |
| **VIN / Text** | *Generic* | `String` |

## 🛠️ Handling Connection Issues

The `BluetoothAdapterOBD2` uses a **Greedy Discovery** approach:

1. It connects to the device.
2. It iterates through *every* service and characteristic.
3. It explicitly looks for standard writers (`FFF2`, `FFE1`) but falls back to *any* writable characteristic if standard ones aren't found.
4. It subscribes to *all* notifying characteristics.

This ensures compatibility with cheap "clone" ELM327 adapters that often use random UUIDs.

## 📄 License

This project is licensed under the **Mozilla Public License 2.0**.