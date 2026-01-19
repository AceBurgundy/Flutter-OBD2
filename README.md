# 🚗 Flutter-OBD2 — A Modern Flutter OBD-II SDK

[![pub.dev](https://img.shields.io/pub/v/obd2.svg)](https://pub.dev/packages/obd2)
[![license](https://img.shields.io/badge/license-MPL%202.0-blue.svg)](https://www.mozilla.org/en-US/MPL/2.0/)
[![platform](https://img.shields.io/badge/platform-Flutter-blue.svg)](https://flutter.dev)
[![bluetooth](https://img.shields.io/badge/Bluetooth-BLE-0096FF.svg)](#)

A **modern, diagnostic-standard–aware OBD-II SDK for Flutter** designed for **live telemetry**, **clean APIs**, and **extensible vehicle diagnostics**.

This package works with **ELM327-compatible Bluetooth Low Energy (BLE) OBD-II adapters** and focuses on:

* 🚀 Simple, session-based telemetry streaming
* 🧠 Diagnostic-standard-scoped PID definitions
* 🧩 Pluggable transport adapters (Bluetooth, Serial, future)
* ⚡ High-performance formula evaluation with caching
* 🧼 Clean architecture with minimal abstraction overhead

## ✨ Key Features

* ✅ Bluetooth Low Energy (BLE) OBD-II adapters
* ✅ Live telemetry streaming (RPM, coolant temp, etc.)
* ✅ Diagnostic-standard abstraction (SAE J1979 today)
* ✅ Standard-scoped PID definitions (no global PID confusion)
* ✅ Cached math expression evaluation
* ✅ Adapter auto-initialization (AT command pipeline)
* ✅ Simple `double` telemetry values (no unnecessary wrappers)
* ✅ Dashboard-friendly, Flutter-native API

## 📦 Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  obd2: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## 🔌 Supported Adapters

* ELM327 BLE adapters
* OBDLink BLE
* Most BLE-based OBD-II scanners

> ⚠️ Classic Bluetooth (SPP) adapters are **not supported**.

## 🧠 Architecture Overview

The SDK follows a **clear responsibility split**:

```
BluetoothAdapterOBD2
        ↓
  DiagnosticStandard (SAE J1979, etc.)
        ↓
     DetailedPID (ID + description + formula)
        ↓
     double (telemetry value)
```

### Key ideas

* The **adapter** owns the OBD-II engine
* The **diagnostic standard** defines how data is requested and parsed
* **PIDs are scoped to their diagnostic standard**
* Telemetry values are returned as plain `double`

No global PID maps.
No magic strings.
No unnecessary wrappers.

## 🧩 Diagnostic Standards

Diagnostic standards are **explicit and injectable**.

Currently supported:

* ✅ **SAE J1979** (OBD-II Mode 01 telemetry)

Planned:

* ⏳ ISO 15765 (CAN)
* ⏳ ISO 9141
* ⏳ ISO 14230 (KWP2000)

Each standard:

* Defines its own supported PIDs
* Knows how to build ECU requests
* Knows how to parse ECU responses

## 🚀 Quick Start

### 1️⃣ Connect to an OBD-II Adapter

```dart
await FlutterBluePlus.adapterState.first;

final devices = await FlutterBluePlus.bondedDevices;
final device = devices.first;

final DiagnosticStandard standard = SaeJ1979();

final scanner = BluetoothAdapterOBD2(
  diagnosticStandard: standard,
);

await scanner.connect(device); // auto-initializes adapter
```

### 2️⃣ Start a Telemetry Session

Telemetry is streamed through a **session object**:

```dart
final session = scanner.stream(
  parameterIDs: [standard.detailedPIDs.rpm],
  onData: (data) {
    final rpm = data[standard.detailedPIDs.rpm];
    if (rpm != null) {
      print('RPM: $rpm');
    }
  },
);
```

Stop the session when done:

```dart
session.stop();
```

## 📊 Telemetry Model

Telemetry values are returned as **plain doubles**.

Why?

* No fake abstraction
* No PID-specific subclasses
* Formula already defines meaning and unit

```dart
Map<DetailedPID, double>
```

Each `DetailedPID` contains:

* Parameter ID (`010C`)
* Human-readable description
* Formula used to compute the value

## 🧠 PID Scoping (Important)

PIDs are **scoped to their diagnostic standard**:

```dart
standard.detailedPIDs.rpm
```

This avoids ambiguity when multiple standards define similar concepts
(e.g. RPM in SAE J1979 vs another protocol).

## ⚡ Performance Optimizations

* 🧠 Cached parsed math expressions per PID
* 🧮 One-time formula compilation
* 🔁 ECU-synchronized polling loop
* 🚫 No repeated parsing or reflection

Designed for:

* Real-time dashboards
* HUDs
* Vehicle monitoring apps

## 🔮 Roadmap

* 🚧 Diagnostic Trouble Codes (DTCs)
* 🚧 Clear fault codes
* 🚧 Additional diagnostic standards
* 🚧 More telemetry PIDs
* 🚧 Protocol auto-detection
* 🚧 Multi-PID batching optimizations

## 🧪 API Status

* 🚀 Actively developed
* 🧪 API stabilizing
* 🧱 Designed for long-term extensibility

Breaking changes will be documented clearly.

## 📄 License

Licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.

* ✔ Commercial use allowed
* ✔ Modification allowed
* ✔ Binary distribution allowed

You must:

* Share modifications to MPL-licensed files

🔗 [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/)

## 🤝 Contributing

Contributions are welcome:

* Bug reports
* New diagnostic standards
* Additional PID definitions
* Documentation improvements

Open an issue or submit a pull request.

## ⭐ Support the Project

If this project helped you:

* ⭐ Star the repo
* 🐛 Report issues
* 💡 Share ideas
