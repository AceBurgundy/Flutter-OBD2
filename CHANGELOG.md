## 0.10.2

- Added human-perception telemetry throttling to EDF scheduler to prevent unnecessary high-frequency polling
- Introduced minimum human-visible interval control for telemetry streaming
- Reduced ELM327 and BLE adapter load without affecting perceived real-time updates
- Improved scheduler stability under high PID counts
- Minor internal scheduler optimizations and documentation improvements
- No breaking API changes
  
## 0.10.1

- Fix FakeAdapter to support service-level execution (sendService / sendServiceWithPID)
- No runtime changes
  
## 0.10.0

- Refactored core AdapterOBD2 to use service-level execution (sendService, sendServiceWithPID)
- Added concurrency-safe command lifecycle with strict request isolation
- Replaced recursive polling with EDF (Earliest Deadline First) scheduler
- Implemented token bucket rate limiter (QPS governor)
- Added EMA-based adaptive latency control for telemetry streaming
- Expanded SAE J1979 PID coverage (fuel trims, rail pressure, catalyst temps, O2 sensors, etc.)
- Improved Mode 02 (Freeze Frame) with proper DTC decoding and automatic Mode 01 → Mode 02 PID mapping (still experimental)
- Improved Mode 03 (Read DTCs) with standards-compliant service-level execution (still experimental)
- Improved Mode 04 (Clear DTCs) with proper positive-response validation (still experimental)
- Refactored DetailedPID (added unit, renamed bestPollingIntervalMs → pollingIntervalMs)
- Introduced strongly-typed TelemetryData snapshot container
- Added OdometerEngine with Riemann-based distance integration and safety guards
- Updated TelemetryProvider to align with static PID definitions and new telemetry engine

## 0.9.0

- Initial public release
- SAE J1979 Mode 01 (Live Telemetry)
- Mode 02 (Freeze Frame) – Experimental
- Mode 03 (Read DTCs) – Experimental
- Mode 04 (Clear DTCs) – Experimental
- BLE transport via flutter_blue_plus
- Type-safe DetailedPID system
- Smart polling engine