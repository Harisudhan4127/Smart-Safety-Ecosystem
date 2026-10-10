import 'dart:math' as math;

/// One inertial measurement, in the units the vehicle firmware reports.
///
/// Accelerometer axes are in g, gyroscope axes in degrees per second. Raw
/// values are preserved as received: filtering happens in [MovingAverage] and
/// the advanced screens show both the raw and filtered streams.
class ImuSample {
  const ImuSample({
    required this.timestamp,
    required this.accelXG,
    required this.accelYG,
    required this.accelZG,
    required this.gyroXDps,
    required this.gyroYDps,
    required this.gyroZDps,
  });

  final DateTime timestamp;
  final double accelXG;
  final double accelYG;
  final double accelZG;
  final double gyroXDps;
  final double gyroYDps;
  final double gyroZDps;

  /// Magnitude of the acceleration vector in g. At rest this is ~1.0 g, so a
  /// 3.5 g impact threshold corresponds to roughly 2.5 g of change.
  double get accelerationMagnitudeG => math.sqrt(
        accelXG * accelXG + accelYG * accelYG + accelZG * accelZG,
      );

  /// Combined rotation rate in degrees per second. Used as a secondary
  /// rollover signal alongside the gravity-derived tilt.
  double get rotationMagnitudeDps => math.sqrt(
        gyroXDps * gyroXDps + gyroYDps * gyroYDps + gyroZDps * gyroZDps,
      );

  /// Angle between the device's gravity vector and the road plane, in degrees.
  /// 0\u00B0 is upright, 90\u00B0 is fully on its side.
  double get tiltDegrees {
    // With z pointing up at rest, the tilt is the angle between gravity and the
    // z axis; arccos(z / |a|) gives 0 when z dominates.
    final mag = accelerationMagnitudeG;
    if (mag <= 0) return 0;
    final ratio = (accelZG / mag).clamp(-1.0, 1.0);
    return math.acos(ratio) * 180.0 / math.pi;
  }

  static ImuSample rest(DateTime timestamp) => ImuSample(
        timestamp: timestamp,
        accelXG: 0,
        accelYG: 0,
        accelZG: 1.0,
        gyroXDps: 0,
        gyroYDps: 0,
        gyroZDps: 0,
      );
}

/// The filtered view of the IMU stream that the detector actually thresholds.
class ImuSnapshot {
  const ImuSnapshot({
    required this.sample,
    required this.accelerationMagnitudeG,
    required this.rotationMagnitudeDps,
    required this.tiltDegrees,
  });

  final ImuSample sample;
  final double accelerationMagnitudeG;
  final double rotationMagnitudeDps;
  final double tiltDegrees;

  DateTime get timestamp => sample.timestamp;
}