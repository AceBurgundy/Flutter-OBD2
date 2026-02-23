# 🚗 Flutter OBD2

[![CI](https://github.com/AceBurgundy/Flutter-OBD2/actions/workflows/flutter.yml/badge.svg)](https://github.com/AceBurgundy/Flutter-OBD2/actions)

A **modern SAE J1979 OBD-II SDK for Flutter**.

Flutter OBD2 provides a clean, type-safe, and transport-focused interface for communicating with **ELM327-compatible Bluetooth Low Energy (BLE)** adapters using the **SAE J1979 (Generic OBD-II)** standard.

> ⚙️ This SDK intentionally supports **SAE J1979 only**.  
> It does **not** implement UDS or manufacturer-specific diagnostic protocols.

## 📦 Current Release Status

**Version:** `0.9.x` (Stabilization Phase)

- ✅ Mode 01 (Live Telemetry) — Fully validated
- 🚧 Modes 02–04 — Implemented, limited real-world validation
- 🧪 Full unit test coverage with CI integration
- 🏗 Architecture finalized for 1.0 milestone

## 📊 Example Dashboard

![Telemetry Dashboard](screenshots/dashboard.jpg)

# ✨ Why Flutter OBD2?

Most OBD libraries:

- Mix transport and protocol logic  
- Expose raw hex responses  
- Require manual PID parsing  
- Overload the ECU with unsafe polling  

Flutter OBD2 provides:

- ✅ Clean layered architecture  
- ✅ Strongly typed `DetailedPID<T>` system  
- ✅ Intelligent, collision-safe polling engine  
- ✅ Formula evaluation engine  
- ✅ Greedy BLE compatibility layer  
- ✅ Strict SAE J1979 implementation  

This is a **diagnostic SDK**, not just a Bluetooth wrapper.

# 🏗 Architecture Overview

```
BluetoothAdapterOBD2  (BLE Transport)
        ↓
AdapterOBD2           (Core Engine)
        ↓
SaeJ1979 Protocol
        ├── telemetry
        ├── freezeFrame
        ├── readCodes
        └── clearCodes
```

## 🔌 Transport Layer — `BluetoothAdapterOBD2`

Handles:

- BLE connection
- GATT discovery
- Characteristic subscription
- Raw byte streaming
- ELM327 initialization

## 🧠 Core Engine — `AdapterOBD2`

Handles:

- ASCII encoding / decoding
- Command lifecycle
- Response buffering
- Formula evaluation
- PID dispatching

## 🏎 SAE J1979 Protocol

Provides:

- PID definitions
- Mode grouping
- Byte extraction logic
- Diagnostic parsing rules

# 🚀 Getting Started

## 1️⃣ Installation

```yaml
dependencies:
  obd2: ^0.9.0
  flutter_blue_plus: ^2.1.0
```

## 2️⃣ Connect to Adapter

```dart
import 'package:obd2/obd2.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final adapter = BluetoothAdapterOBD2();

await adapter.connect(myBluetoothDevice);
```

The adapter automatically:

- Connects
- Discovers services
- Subscribes to notify/indicate characteristics
- Selects writable pipe
- Sends AT initialization commands
- Negotiates protocol

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

// Stop later
session.stop();
```

### Telemetry Engine Features

- Respects `bestPollingIntervalMs`
- Prevents ECU flooding
- Collision-safe recursive loop
- Type-safe PID retrieval
- Timeout resilient

# 🔍 Supported PID Discovery

```dart
final supported = await adapter.protocol.telemetry
    .detectSupportedTelemetry(validateAccessibility: true);

print("Supported: $supported");
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

Each PID is defined as:

```dart
DetailedPID<T>
```

Compile-time enforced return types:

| Type           | Example        |
|---------------|---------------|
| `double`       | RPM            |
| `String`       | Fuel Type      |
| `List<double>` | Lambda         |
| `List<int>`    | Status Bitmask |

No manual casting required.

# 🔌 BLE Compatibility Strategy

`BluetoothAdapterOBD2` uses a **Greedy Discovery Model**:

1. Connect
2. Discover all services
3. Subscribe to every notify/indicate characteristic
4. Prefer standard ELM327 UUIDs (FFF2 / FFE1)
5. Initialize adapter

Designed for low-cost ELM327 clones.

# 🧠 Public API Overview

## Core

```dart
await adapter.connect(device);
await adapter.disconnect();
```

## SAE J1979 Access

```dart
adapter.protocol.telemetry
adapter.protocol.freezeFrame
adapter.protocol.readCodes
adapter.protocol.clearCodes
```

# 🧪 Testing & CI

- Full unit tests
- `dart analyze` enforced
- GitHub Actions CI
- Mock adapter testing (no hardware required)

# ⚠️ Testing Status

| Mode    | Validation Level |
|----------|------------------|
| Mode 01 | ✅ Fully Tested |
| Mode 02 | 🚧 Partial |
| Mode 03 | 🚧 Partial |
| Mode 04 | 🚧 Partial |

Full real-world validation targeted for v1.0.0.

# 🎯 Road to 1.0

Version 1.0.0 will signify:

- Complete real-world validation
- Stable API commitment
- Production-grade diagnostic reliability

# 🧭 Design Philosophy

Flutter OBD2:

- Implements SAE J1979 correctly
- Avoids unnecessary abstraction
- Separates transport from diagnostics
- Prioritizes clarity over feature bloat
- Is engineered for long-term stability

# 📄 License

Licensed under the **Mozilla Public License 2.0**.