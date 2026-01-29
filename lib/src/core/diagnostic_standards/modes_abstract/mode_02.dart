import '../../../../obd2.dart';
import '../../adapter_obd2.dart';

/// Abstract base class for Freeze Frame data (Mode 02).
///
/// Freeze Frame data is a snapshot of vehicle sensor data recorded by the ECU
/// at the exact moment a Diagnostic Trouble Code (DTC) was triggered.
abstract class FreezeFrameMode {
  /// Creates a freeze frame mode controller.
  FreezeFrameMode();

  /// OBD-II service mode identifier.
  static const String mode = '02';

  // --- Special Freeze Frame PIDs ---

  /// The Diagnostic Trouble Code (DTC) that caused this freeze frame to be stored.
  DetailedPID<String> get dtcCausingFreeze;

  // --- Standard Sensors (Snapshot) ---

  /// Engine speed at the moment of the error.
  DetailedPID<double> get rpm;

  /// Vehicle speed at the moment of the error.
  DetailedPID<double> get speed;

  /// Engine coolant temperature at the moment of the error.
  DetailedPID<double> get coolantTemperature;

  /// Calculated engine load at the moment of the error.
  DetailedPID<double> get engineLoad;

  /// Intake manifold pressure at the moment of the error.
  DetailedPID<double> get intakeManifoldPressure;

  /// Fetches the freeze frame data for the requested PIDs.
  ///
  /// ### Parameters:
  /// - [detailedPIDs]: List of PIDs to request.
  /// - [adapter]: The connected OBD-II adapter.
  ///
  /// ### Returns:
  /// - (`Future<TelemetryData>`): The snapshot data container.
  Future<TelemetryData> getFreezeFrameData({
    required List<DetailedPID> detailedPIDs,
    required AdapterOBD2 adapter,
  });
}