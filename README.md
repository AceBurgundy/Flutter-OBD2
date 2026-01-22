# 🚗 Flutter-OBD2 — A Modern Flutter OBD-II SDK

A **modern, diagnostic-standard–aware OBD-II SDK for Flutter**, designed for **live telemetry streaming**, **clean APIs**, and **long-term extensibility**.

This package works with **ELM327-compatible Bluetooth Low Energy (BLE) OBD-II adapters** and focuses on:

* 🚀 Simple, session-based telemetry polling
* 🧠 Diagnostic-standard–scoped PID definitions
* 🧩 Pluggable transport adapters (Bluetooth today, more later)
* ⚡ High-performance formula evaluation with caching
* 🧼 Clean architecture with minimal abstraction overhead

## ✨ Key Features

* ✅ Bluetooth Low Energy (BLE) OBD-II adapters
* ✅ Live telemetry polling (RPM, coolant temp, etc.)
* ✅ Diagnostic standard abstraction (SAE J1979 today)
* ✅ **Standard-scoped & Mode-aware PID definitions**
* ✅ Cached math expression evaluation
* ✅ Adapter auto-initialization (AT command pipeline)
* ✅ Simple `double` telemetry values (no unnecessary wrappers)
* ✅ Dashboard-friendly, Flutter-native API

## 📦 Installation

Add to your `pubspec.yaml`:

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

The SDK follows a **clear and intentional responsibility split**:

```
BluetoothAdapterOBD2
        ↓
  DiagnosticStandard (SAE J1979)
        ↓
      Modes (Telemetry, Identity, etc.)
        ↓
      DetailedPID (ID + description + formula)
        ↓
        double

```

### Core Principles

* The **adapter** owns the OBD-II engine and polling loop.
* The **diagnostic standard** defines:
* Supported PIDs (organized by **Modes**).
* How requests are built.
* How ECU responses are parsed.


* **PIDs are scoped to their diagnostic standard and specific mode.**
* Telemetry values are returned as **plain `double**`.

No global PID maps.

No magic strings.

No unnecessary telemetry subclasses.

## 🧩 Diagnostic Standards

Diagnostic standards are **explicit and injectable**.

### Currently Supported

* ✅ **SAE J1979** (OBD-II Modes 01, 02, 09)

### Planned

* ⏳ ISO 15765 (CAN)
* ⏳ ISO 9141
* ⏳ ISO 14230 (KWP2000)

## 🚀 Quick Start

### 1️⃣ Connect to an OBD-II Adapter

```dart
await FlutterBluePlus.adapterState.first;

final devices = await FlutterBluePlus.bondedDevices;
final device = devices.first;

final SaeJ1979 standard = SaeJ1979();

final scanner = BluetoothAdapterOBD2(
  diagnosticStandard: standard,
);

await scanner.connect(device); // auto-initializes adapter

```

### 2️⃣ Start a Telemetry Polling Session

Access the specific mode you need (e.g., `telemetry` for Mode 01) to keep your code clean:

```dart
// Extract the mode for cleaner access
final telemetry = standard.modes.telemetry;

final session = scanner.poll(
  detailedPIDs: [
    telemetry.rpm,
    telemetry.coolantTemperature,
  ],
  onData: (data) {
    final rpm = data[telemetry.rpm];
    final temp = data[telemetry.coolantTemperature];
    
    if (rpm != null) print('RPM: $rpm');
    if (temp != null) print('Temp: $temp');
  },
);

```

Stop the session when done:

```dart
session.stop();

```

## 📊 Telemetry Model

Telemetry values are returned as **plain `double**`.

```dart
Map<DetailedPID, double>

```

Each `DetailedPID` contains:

* Parameter ID (e.g. `010C`)
* Human-readable description
* Formula used to compute the value

## 🧠 PID Scoping (Important)

PIDs are **scoped to their diagnostic standard and organized by mode**. This structure prevents "namespace pollution" and ensures you are requesting the correct data for the correct mode.

```dart
final modes = standard.modes;

// Mode 01: Live Telemetry
modes.telemetry.rpm

// Mode 09: Vehicle Identity
modes.identity.vin

// Mode 02: Freeze Frame (Snapshot)
modes.snapshots.rpm

```

No global `rpm`.

No guessing which mode a PID belongs to.

## ⚡ Performance Optimizations

* 🧠 Cached parsed math expressions per PID
* 🧮 One-time formula compilation
* 🔁 ECU-synchronized polling loop
* 🚫 No repeated parsing or reflection

## 🔮 Roadmap

* 🚧 Diagnostic Trouble Codes (DTCs)
* 🚧 Clear fault codes
* 🚧 Additional diagnostic standards
* 🚧 Expanded telemetry coverage
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
