class PIDInformation {
  final String parameterID;
  final String name;
  final String formula;

  const PIDInformation(this.parameterID, this.name, this.formula);
}

abstract class TelemetryValue<T> {
  final T value;
  final DateTime timestamp;

  TelemetryValue(this.value) : timestamp = DateTime.now();
}

class DTCInformation {
  final String code;
  final String description;

  const DTCInformation(this.code, this.description);
}

class DiagnosticInfo {
  final String code;
  final String description;
  final String severity;
  final List<String> possibleCauses;

  const DiagnosticInfo(this.code, this.description, this.severity, this.possibleCauses);
}

class TelemetryData {
  final List<TelemetryValue<dynamic>> values;

  TelemetryData(this.values);
}

class VehicleInfo {
  final String vin;
  final String make;
  final String model;
  final int year;

  const VehicleInfo(this.vin, this.make, this.model, this.year);
}

class DTCHistory {
  final DTCInformation dtc;
  final DateTime detectedTime;
  final bool isActive;

  const DTCHistory(this.dtc, this.detectedTime, this.isActive);
}

class EngineData extends TelemetryValue<double> {
  final String parameterID;
  final String name;

  EngineData(super.value, this.parameterID, this.name);
}
