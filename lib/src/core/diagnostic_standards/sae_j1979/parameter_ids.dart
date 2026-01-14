import 'package:obd2/src/models.dart';

const PIDInformation rpm = PIDInformation(
  '010C',
  'RPM',
  '([0] * 256 + [1]) / 4',
);
