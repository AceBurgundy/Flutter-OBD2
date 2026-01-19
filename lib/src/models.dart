class DetailedPID {
  final String parameterID;
  final String name;
  final String formula;

  const DetailedPID(this.parameterID, this.name, this.formula);
}

abstract class TelemetryValue<T> {
  final T value;
  final DateTime timestamp;

  TelemetryValue(this.value) : timestamp = DateTime.now();
}