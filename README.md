# 🚗 Flutter-OBD2 – Modern Flutter OBD-II SDK (Being Worked On)

[![pub.dev](https://img.shields.io/pub/v/obd2.svg)](https://pub.dev/packages/obd2)
[![license](https://img.shields.io/badge/license-MPL%202.0-blue.svg)](https://www.mozilla.org/en-US/MPL/2.0/)
[![platform](https://img.shields.io/badge/platform-Flutter-blue.svg)](https://flutter.dev)
[![bluetooth](https://img.shields.io/badge/Bluetooth-BLE-0096FF.svg)](#)

A **modern, strongly-typed, diagnostic-standard–aware OBD-II SDK for Flutter** built for dashboards, telemetry streaming, and professional vehicle diagnostics.

This package is designed to work with **ELM327-compatible Bluetooth Low Energy (BLE) OBD-II adapters** and emphasizes:

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

This package is built with **clean layering and protocol abstraction**:

```
Bluetooth Adapter
      ↓
OBD2BluetoothService
      ↓
BluetoothOBD2
      ↓
DiagnosticStandard (SAE J1979 / ISO 15765 / ...)
      ↓
PIDInformation
      ↓
TelemetryValue<T>
      ↓
Stream<Map<String, TelemetryValue>>
```

## 🧩 Diagnostic Standards

Diagnostic standards are **runtime-injectable**, not hardcoded.

Currently supported:

* ✅ **SAE J1979** (OBD-II Mode 01 telemetry)

Planned:

* ⏳ ISO 15765 (CAN)
* ⏳ ISO 9141
* ⏳ ISO 14230 (KWP2000)

## 🚀 Quick Start

### 1️⃣ Initialize Bluetooth

```dart
await OBD2BluetoothService.initialize();

final service = OBD2BluetoothService();
final device = await service.connect(selectedDevice);
```

### 2️⃣ Create OBD2 Instance

```dart
final obd2 = BluetoothOBD2(
  bluetoothService: service,
  diagnosticStandard: SaeJ1979Standard(),
);

obd2.connection = device!;
```

### 3️⃣ Initialize Adapter (AT Commands)

```dart
await obd2.initializeAdapter();
```

This automatically sends:

* `AT Z` (reset)
* `AT E0` (echo off)
* `AT L0` (linefeeds off)
* `AT SP 0` (auto protocol)

### 4️⃣ Stream Live Telemetry

```dart
obd2.listenTelemetry(
  on: [
    rpm, // from diagnostic_standards/sae_j1979/parameter_ids.dart
  ],
);
```

### 5️⃣ Listen to Telemetry Stream

```dart
obd2.telemetryStream.listen((telemetry) {
  final rpmValue = telemetry['010C'] as RpmTelemetry;
  print('RPM: ${rpmValue.value}');
});
```

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

This makes the SDK:

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

You are free to:

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

Feel free to open an issue or submit a pull request.

## ⭐ Support the Project

If this project helps you build something cool:

* ⭐ Star the repo
* 🐛 Report issues
* 🧠 Share ideas
