/// Kmh: Kilometers per Hour
/// Km: Kilometers
/// 
/// Calculation engine for tracking distance traveled using Riemann integration.
/// 
/// The [OdometerEngine] tracks cumulative distance by calculating the 
/// time delta between updates and multiplying by the current speed.
class OdometerEngine {
  /// The total accumulated distance in kilometers.
  double _currentOdometerKm;

  /// The timestamp of the most recent update, used to calculate time deltas.
  DateTime? _lastTimestamp;

  /// The maximum allowed time gap between updates before 
  /// the engine resets the baseline to prevent integration spikes.
  static const Duration _maxDelta = Duration(minutes: 1);

  /// Conversion factor for calculating hours from milliseconds.
  static const double _millisecondsPerHour = 3600000.0;

  /// Creates a new instance of [OdometerEngine] starting at a specific value.
  /// 
  /// ### Parameters
  /// - [_currentOdometerKm] (`double`): The initial odometer reading in kilometers.
  OdometerEngine(this._currentOdometerKm);

  /// Initializes the tracking period with a starting timestamp.
  ///
  /// Use [timestamp] to set the baseline for the next [update] call.
  ///
  /// ### Parameters
  /// - [timestamp] (`DateTime`): The current time at the start of tracking.
  void start(DateTime timestamp) {
    _lastTimestamp = timestamp;
  }

  /// Stops integration by clearing the internal baseline timestamp.
  ///
  /// Future calls to [update] will reinitialize timing instead of 
  /// accumulating distance.
  void stop() {
    _lastTimestamp = null;
  }

  /// Resets the odometer reading to zero or a specific value.
  ///
  /// Use [newValue] to restart the odometer from a specific distance. 
  /// This also clears the [_lastTimestamp] to prevent calculation jumps.
  ///
  /// ### Parameters
  /// - [newValue] (`double`): The value to set the odometer to. Defaults to 0.0.
  void reset([double newValue = 0.0]) {
    _currentOdometerKm = newValue;
    _lastTimestamp = null;
  }

  /// Updates the odometer reading based on the current speed and elapsed time.
  ///
  /// This method calculates the distance covered since the last update.
  /// Includes guards against backwards system clocks and gaps exceeding [_maxDelta].
  ///
  /// ### Parameters
  /// - [speedKmh] (`double`): The current speed in kilometers per hour.
  /// - [timestamp] (`DateTime`): The current time of this reading.
  ///
  /// ### Usage
  /// ```dart
  /// odometer.update(65.5, DateTime.now());
  /// ```
  void update(double speedKmh, DateTime timestamp) {
    // 1. Initial baseline check
    if (_lastTimestamp == null) {
      _lastTimestamp = timestamp;
      return;
    }

    // 2. Backwards Time Guard
    // Prevents negative distance if the system clock synchronizes backwards.
    if (timestamp.isBefore(_lastTimestamp!)) {
      _lastTimestamp = timestamp;
      return;
    }

    final Duration delta = timestamp.difference(_lastTimestamp!);

    // 3. Precision Sanity Delta Guard (Fail-safe)
    if (delta > _maxDelta) {
      _lastTimestamp = timestamp;
      return;
    }

    // Update the reference timestamp before speed filtering to ensure
    // stationary time isn't "carried over" into the next moving calculation.
    _lastTimestamp = timestamp;

    // Filter out GPS drift/noise (speeds below 0.5 km/h)
    if (speedKmh < 0.5) return;

    // Convert duration to fractional hours for distance calculation.
    final double elapsedHours = delta.inMilliseconds / _millisecondsPerHour;

    // Standard Riemann Integration: distance = speed * time
    _currentOdometerKm += speedKmh * elapsedHours;
  }

  /// Gets the current total distance recorded.
  ///
  /// ### Returns
  /// - (`double`): The total distance traveled in kilometers.
  double get value => _currentOdometerKm;
}