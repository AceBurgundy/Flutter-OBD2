# 🚗 Flutter OBD2

A **production-ready SAE J1979 OBD-II SDK for Flutter**.

Flutter OBD2 provides a clean, type-safe, and transport-agnostic interface for communicating with **ELM327-compatible Bluetooth Low Energy (BLE)** adapters using the **SAE J1979 (Generic OBD-II)** standard.

> ⚙️ This SDK is intentionally focused on **SAE J1979 only**.
> It does **not** implement UDS or manufacturer-specific protocols.

## 📊 Example Dashboard

![Telemetry Dashboard](screenshots/dashboard.jpg)

## ✨ Why This Package?

Most OBD libraries:

* Mix transport and protocol logic
* Expose raw hex responses
* Require manual PID parsing
* Overload the ECU with bad polling loops

Flutter OBD2:

* ✅ Clean layered architecture
* ✅ Type-safe PID definitions
* ✅ Intelligent polling engine
* ✅ Formula evaluation engine
* ✅ Greedy BLE compatibility layer
* ✅ SAE J1979-focused design

This is a **diagnostic SDK**, not just a Bluetooth wrapper.

# 📦 Architecture Overview

The SDK follows a protocol-bound layered design.

```
BluetoothAdapterOBD2 (BLE Transport)
        ↓
AdapterOBD2 (Core Engine)
        ↓
protocol (SaeJ1979)
        ├── telemetry
        ├── freezeFrame
        ├── readCodes
        └── clearCodes
```

### Layer Responsibilities

### 🔌 Transport Layer

* BLE connection
* GATT discovery
* Characteristic subscription
* Raw byte streaming

### 🧠 Core Engine (`AdapterOBD2`)

* ELM327 initialization
* ASCII encoding / decoding
* Command lifecycle
* Response buffering
* Formula evaluation
* PID dispatching

### 🏎️ SAE J1979 Protocol

* PID definitions
* Mode grouping
* Byte extraction rules
* Diagnostic parsing

# 🚀 Getting Started

## 1️⃣ Installation

```yaml
dependencies:
  obd2: ^1.0.0
  flutter_blue_plus: ^1.30.0
```

## 2️⃣ Connect to an Adapter

```dart
import 'package:obd2/obd2.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final adapter = BluetoothAdapterOBD2();

await adapter.connect(myBluetoothDevice);
```

The adapter automatically:

* Connects
* Discovers services
* Subscribes to notify/indicate characteristics
* Selects writable pipe
* Sends AT initialization commands
* Negotiates protocol

No protocol injection required.

# 📡 Mode 01 — Live Telemetry (Production Ready)

```dart
final telemetry = adapter.protocol.telemetry;

final session = telemetry.stream(
  detailedPIDs: [
    telemetry.rpm,
    telemetry.speed,
    telemetry.coolantTemperature,
  ],
  onData: (TelemetryData data) {
    final rpm = data.get(telemetry.rpm);

    if (rpm != null) {
      print("RPM: $rpm");
    }
  },
);

// Stop streaming later
session.stop();
```

### Features

* Respects `bestPollingIntervalMs`
* Prevents ECU overload
* Collision-safe command loop
* Fully type-safe

# 🔍 Supported PID Discovery

Detect real ECU support:

```dart
final supported = await adapter.protocol.telemetry.detectSupportedTelemetry(validateAccessibility: true);

print("Supported PIDs: $supported");
```

# 🧊 Mode 02 — Freeze Frame

```dart
final freeze = adapter.protocol.freezeFrame;

final snapshot = await freeze.getFrameData(
  detailedPIDs: [
    freeze.rpm,
    freeze.speed,
  ],
);

print(snapshot.get(freeze.rpm));
```

# 🚨 Mode 03 — Read Diagnostic Trouble Codes

```dart
final codes = await adapter.protocol.readCodes.getDTCs();

print("Fault Codes: $codes");
```

# 🧹 Mode 04 — Clear Diagnostic Trouble Codes

```dart
final success = await adapter.protocol.clearCodes.eraseDTCs();

print("Cleared: $success");
```

# 🧬 Type-Safe PID System

Every PID is defined as:

```dart
DetailedPID<T>
```

Return types are enforced at compile time:

| Type           | Example        |
| -------------- | -------------- |
| `double`       | RPM            |
| `String`       | Fuel Type      |
| `List<double>` | Lambda         |
| `List<int>`    | Status Bitmask |

No manual casting required.

# 📊 Supported Mode 01 PIDs

Available via:

```dart
adapter.protocol.telemetry
```

| PID           | Accessor             | Return Type    |
| ------------- | -------------------- | -------------- |
| Engine RPM    | `rpm`                | `double`       |
| Vehicle Speed | `speed`              | `double`       |
| Coolant Temp  | `coolantTemperature` | `double`       |
| Engine Load   | `engineLoad`         | `double`       |
| Fuel Level    | `fuelLevel`          | `double`       |
| Mass Air Flow | `massAirFlow`        | `double`       |
| Odometer      | `odometer`           | `double`       |
| Lambda        | `lambdaBank1Sensor1` | `List<double>` |
| Fuel Type     | `fuelType`           | `String`       |

# 🔌 BLE Compatibility Strategy

`BluetoothAdapterOBD2` uses a **Greedy Discovery Model**:

1. Connects to device
2. Discovers all services
3. Subscribes to every notify/indicate characteristic
4. Selects the best writable characteristic (FFF2/FFE1 preferred)
5. Initializes adapter

Designed for low-cost ELM327 clones.

# 🧠 Public API Overview

## Core Classes

### `BluetoothAdapterOBD2`

BLE transport implementation.

```dart
await adapter.connect(device);
await adapter.disconnect();
```

### `AdapterOBD2`

Abstract core engine (extended internally).

### `adapter.protocol`

Exposes SAE J1979 functionality:

* `telemetry`
* `freezeFrame`
* `readCodes`
* `clearCodes`

### `Telemetry`

```dart
stream(...)
query(...)
detectSupportedTelemetry(...)
calculateOdometer(...)
```

### `ReadCodes`

```dart
getDiagnosticTroubleCodes()
```

### `ClearCodes`

```dart
clearDiagnosticTroubleCodes()
```

# ⚠️ Testing Status

| Mode    | Status                |
| ------- | --------------------- |
| Mode 01 | ✅ Fully Tested        |
| Mode 02 | 🚧 Limited Validation |
| Mode 03 | 🚧 Limited Validation |
| Mode 04 | 🚧 Limited Validation |

More real-vehicle validation planned for 1.x releases.

# 🎯 Version 1.0 Positioning

Flutter OBD2 v1.0 is:

* Stable for real-time telemetry apps
* Architecturally finalized
* SAE J1979 focused
* BLE optimized
* Suitable for production dashboards and analytics apps

Future roadmap may include:

* Advanced DTC parsing improvements
* UDS extension package (separate)
* CAN frame debugging utilities
* Performance telemetry batching

# 🧭 Design Philosophy

This package:

* Focuses on **doing SAE J1979 correctly**
* Avoids unnecessary multi-protocol abstraction
* Separates transport from diagnostic logic
* Prioritizes stability and clarity over feature overload

# 📄 License

Licensed under the **Mozilla Public License 2.0**.
