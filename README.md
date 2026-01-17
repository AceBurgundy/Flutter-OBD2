# 🚗 Flutter-OBD2 – Modern Flutter OBD-II SDK (Being Worked On)

[![pub.dev](https://img.shields.io/pub/v/obd2.svg)](https://pub.dev/packages/obd2)
[![license](https://img.shields.io/badge/license-MPL%202.0-blue.svg)](https://www.mozilla.org/en-US/MPL/2.0/)
[![platform](https://img.shields.io/badge/platform-Flutter-blue.svg)](https://flutter.dev)
[![bluetooth](https://img.shields.io/badge/Bluetooth-BLE-0096FF.svg)](#)

A **modern, strongly-typed, diagnostic-standard–aware OBD-II SDK for Flutter** built for dashboards, telemetry streaming, and professional vehicle diagnostics.

This package works with **ELM327-compatible Bluetooth Low Energy (BLE) OBD-II adapters** and emphasizes:

* 🚀 **Live telemetry streaming**
* 🧠 **Typed telemetry models**
* 🧩 **Pluggable diagnostic standards**
* ⚡ **High performance with cached formula evaluation**
* 🧼 **Clean architecture & strict separation of concerns**

## ✨ Features

✅ Bluetooth Low Energy (BLE) OBD-II support
✅ Live RPM and telemetry streaming
✅ Strongly typed telemetry values
✅ Diagnostic standard abstraction (SAE J1979, ISO 15765, more coming)
✅ Cached PID formula parsing (huge performance boost)
✅ Adapter auto-configuration (AT command pipeline)
✅ Flutter-native `Stream` API
✅ Dashboard-ready architecture

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

The SDK now uses **adapter-based OBD2 engines**:

```
BluetoothAdapterOBD2  →  OBD2 engine
         ↓
 DiagnosticStandard (SAE J1979 / ISO 15765 / ...)
         ↓
       PIDInformation
         ↓
   TelemetryValue<T>
         ↓
Stream<Map<String, TelemetryValue>>
```

**Key Change:** The adapter now contains the OBD2 engine. Users interact directly with the adapter:

```dart
scanner.telemetryStreamFor([rpm, coolantTemp]).listen((data) {
  print('RPM: ${data[rpm]?.value}');
});
```

No separate OBD2 instance is needed.

## 🧩 Diagnostic Standards

Diagnostic standards are **runtime-injectable**, not hardcoded.

Currently supported:

* ✅ **SAE J1979** (OBD-II Mode 01 telemetry)

Planned:

* ⏳ ISO 15765 (CAN)
* ⏳ ISO 9141
* ⏳ ISO 14230 (KWP2000)

## 🚀 Quick Start

### 1️⃣ Retrieve and Connect a Bluetooth Device

```dart
// Initialize Flutter Blue Plus
await FlutterBluePlus.adapterState.first;

// User retrieves bonded devices
final devices = await FlutterBluePlus.bondedDevices;
final selectedDevice = devices.first;

// Create scanner and connect (auto-initializes OBD-II)
final scanner = BluetoothAdapterOBD2();
await scanner.connect(selectedDevice);
```

### 2️⃣ Stream Telemetry in One Block

```dart
scanner.telemetryStreamFor([rpm, coolantTemp]).listen((data) {
  print('RPM: ${data[rpm]?.value}');
  print('Coolant Temp: ${data[coolantTemp]?.value}');
});
```

✅ **No separate OBD2 engine needed.** Adapter handles all PID requests, parsing, and streaming.

## 📊 Telemetry Models

All telemetry values are **strictly typed**:

```dart
abstract class TelemetryValue<T> {
  final T value;
  final DateTime timestamp;
}
```

Example:

```dart
class RpmTelemetry extends TelemetryValue<double> {
  RpmTelemetry(super.value);
}
```

* Type-safe
* Analyzer-friendly
* UI-friendly

## ⚡ Performance Optimizations

* 🧠 Cached parsed expressions per PID
* 🧮 One-time formula compilation
* 🔁 Continuous ECU-synchronized polling
* 🚫 No repeated parsing or reflection

Perfect for:

* Real-time dashboards
* HUD displays
* Track telemetry
* Motorcycle & automotive apps

## 🔮 Future Plans

🚧 **Diagnostic Trouble Codes (DTCs)**

* Read active & stored fault codes
* Standard-specific decoding
* Human-readable descriptions

🚧 **Erase Diagnostic Codes**

* Clear ECU fault memory
* Reset warning lights

🚧 **More Diagnostic Standards**

* ISO 15765 (CAN)
* ISO 9141
* ISO 14230 (KWP2000)

🚧 **Advanced Telemetry**

* Vehicle speed
* Coolant temperature
* Throttle position
* Fuel level
* Intake pressure

🚧 **Protocol Auto-Detection**

* Automatically select correct diagnostic standard

🚧 **Multi-PID Batching**

* Stream multiple telemetry values simultaneously
* Typed per PID

## 🧪 Stability & API Status

* 🚀 Actively developed
* 🧪 API evolving but stable
* 🧱 Designed for long-term extensibility

## 📄 License

This project is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.

* Use in commercial projects
* Modify the source
* Distribute binaries

You must:

* Share modifications to MPL-licensed files

🔗 [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/)

## 🤝 Contributing

Contributions are welcome!

* Bug reports
* Diagnostic standard implementations
* New telemetry PIDs
* Documentation improvements

Open an issue or submit a pull request.

## ⭐ Support the Project

If this project helps you build something cool:

* ⭐ Star the repo
* 🐛 Report issues
* 🧠 Share ideas
