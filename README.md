# 🚗 Flutter-OBD2 - A Modern Flutter OBD-II SDK

A **modern, diagnostic-standard–aware OBD-II SDK for Flutter**, designed for **live telemetry streaming**, **clean APIs**, and **long-term extensibility**.

This package works with **ELM327-compatible Bluetooth Low Energy (BLE) OBD-II adapters** and focuses on:

* 🚀 Simple, session-based telemetry polling.
* 🧠 Diagnostic-standard–scoped PID definitions.
* 🧩 Pluggable transport adapters (Bluetooth today, more later).
* ⚡ Type-safe value handling (Generic `DetailedPID<T>`).
* 🧼 Clean architecture with minimal abstraction overhead.

## ✨ Key Features

* ✅ **BLE Support:** Optimized for Bluetooth Low Energy adapters (via `flutter_blue_plus`).
* ✅ **Live Streaming:** Smart, priority-based polling loop with "Bus Cool-down" management.
* ✅ **Diagnostic Standards:** Explicit support for **SAE J1979** (Modes 01, 02, 03, 04).
* ✅ **Type Safety:** Generic PIDs return specific types (`double`, `String`, `List<double>`) without manual casting.
* ✅ **Formula Engine:** Built-in math expression evaluator for complex ECU responses.
* ✅ **Fault Management:** Read and clear Diagnostic Trouble Codes (DTCs).

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  obd2: ^1.0.0

```

## 🧠 Architecture Overview

The SDK follows a strict hierarchy of responsibility to ensure the core logic is decoupled from the hardware transport layer.

```
BluetoothAdapterOBD2 (Transport Layer)
        ↓
  DiagnosticStandard (Protocol: SAE J1979)
        ↓
    Service Modes (01 - Telemetry, 03 - Codes, etc.)
        ↓
    DetailedPID<T> (Metadata + Formula)
        ↓
     Parsed Value (double, String, or List)

```

### Core Principles

* **The Adapter** owns the physical connection and the AT command pipeline.
* **The Diagnostic Standard** defines how to build requests and extract bytes.
* **The Mode** organizes PIDs and high-level actions (like streaming or clearing codes).
* **DetailedPIDs** are generic; `DetailedPID<double>` ensures you get a number, while `DetailedPID<String>` returns text.

## 🚀 Quick Start

### 1️⃣ Initialize the Adapter

Connect to a BLE device and let the adapter handle the ELM327 `AT` initialization sequence automatically.

```dart
final SaeJ1979 standard = SaeJ1979();

final adapter = BluetoothAdapterOBD2(
  diagnosticStandard: standard,
);

// Connect and auto-initialize (ATZ, ATE0, etc.)
await adapter.connect(myBluetoothDevice); 

```

### 2️⃣ Start a Live Telemetry Session

Access Mode 01 (`telemetry`) to start a priority-aware stream. The stream respects the `bestPollingIntervalMs` defined for each PID (e.g., RPM updates faster than Fuel Level).

```dart
final telemetry = standard.telemetry;

final session = telemetry.stream(
  adapter: adapter,
  detailedPIDs: [
    telemetry.rpm,
    telemetry.coolantTemperature,
  ],
  onData: (TelemetryData data) {
    // Type-safe access using the PID object
    final double? rpm = data.get(telemetry.rpm);
    final double? temp = data.get(telemetry.coolantTemperature);
    
    print("RPM: $rpm, Temp: $temp");
  },
);

// Stop polling when done
session.stop();

```

## 📊 Diagnostic Capabilities

### ⚡ Mode 01: Live Telemetry

Standard sensors like RPM, Speed, Odometer, and calculated values like AFR.

### ❄️ Mode 02: Freeze Frames

Retrieve a snapshot of sensor data captured at the moment a fault occurred.

### 🛠️ Mode 03 & 04: Trouble Codes

Read confirmed DTCs and clear the Check Engine Light (MIL).

```dart
// Read Codes
final codes = await SAEJ1979ReadCodesMode().getDiagnosticTroubleCodes(adapter);
print("Active Faults: $codes"); // ["P0300", "P0101"]

// Clear Codes
bool success = await SAEJ1979ClearCodesMode().clearDiagnosticTroubleCodes(adapter);

```

## 🧩 PID Scoping & Types

Gone are the days of global maps or magic strings. PIDs are scoped to their standard and return specific types based on the `OBD2QueryReturnValue` enum.

| Return Type | Usage Example | Result |
| --- | --- | --- |
| `double` | `telemetry.rpm` | `750.0` |
| `String` | `telemetry.fuelType` | `"Gasoline"` |
| `List<double>` | `telemetry.lambdaBank1Sensor1` | `[0.98, 0.45]` |
| `status` | `DTC Requests` | `[0x43, 0x01, ...]` |

## ⚡ Performance Optimizations

* **Greedy BLE Subscription:** Subscribes to all notifying characteristics to find the data pipe instantly.
* **Write Without Response:** Uses BLE's fastest write mode where supported.
* **Math Caching:** Formulas are parsed into expression trees for high-frequency evaluation.
* **Bus Cool-down:** Configurable `pollIntervalMs` prevents overwhelming the vehicle's CAN bus.

## 📄 License

Licensed under the **Mozilla Public License 2.0 (MPL-2.0)**. You are free to use this commercially, provided you share modifications made to the library files themselves.
