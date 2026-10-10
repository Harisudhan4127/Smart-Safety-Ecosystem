import 'dart:math' as math;

import '../models/geo.dart';
import '../models/imu.dart';
import '../models/lora.dart';

/// One repeatable, deterministic demonstration scenario.
///
/// Demo Mode scenarios are fully scripted: the same scenario always produces the
/// same samples, the same event and the same outcome. That is what makes a
/// demonstration reproducible and makes the simulation testable.
class Scenario {
  const Scenario({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.samplesPerSecond,
    required this.build,
    this.expectedOutcome = TransmissionOutcome.acknowledged,
    this.gpsAvailable = true,
    this.gatewayAvailable = true,
    this.notes = const <String>[],
  });

  final String id;
  final String name;
  final String description;

  /// Total playback length of the scenario.
  final Duration duration;

  /// Sample rate used to generate the IMU stream.
  final double samplesPerSecond;

  /// The script: maps elapsed time to an IMU sample.
  final ImuSample Function(double t, DateTime at) build;

  /// What the simulated radio will report for the packet this scenario
  /// produces.
  final TransmissionOutcome expectedOutcome;

  /// When false, the scenario produces a flagged packet with no position.
  final bool gpsAvailable;

  /// When false, the transmission fails with no gateway in range.
  final bool gatewayAvailable;

  final List<String> notes;

  double get totalSamples => duration.inMilliseconds / 1000.0 * samplesPerSecond;
}

/// The built-in Demo Mode scenario library.
///
/// Each scenario demonstrates one documented behaviour of the system, including
/// the documented alternate paths (no GPS fix, no gateway in range, false alarm
/// cancelled by the driver).
abstract final class Scenarios {
  static GeoFix _fix(double t) => GeoFix(
        // A short deterministic route, so the map panel has something truthful
        // to draw.
        latitude: 12.9716 + math.sin(t / 40) * 0.004,
        longitude: 77.5946 + math.cos(t / 40) * 0.004,
        fixedAt: DateTime.fromMillisecondsSinceEpoch(0)
            .add(Duration(milliseconds: (t * 1000).round())),
        satellites: 9,
        accuracyMetres: 4,
      );

  static ImuSample _cruising(double t, double noise) => ImuSample(
        timestamp: DateTime.fromMillisecondsSinceEpoch(0)
            .add(Duration(milliseconds: (t * 1000).round())),
        // Gentle engine vibration around a 1 g baseline.
        accelXG: noise * 0.02,
        accelYG: noise * 0.02,
        accelZG: 1.0 + noise * 0.03,
        gyroXDps: noise * 2,
        gyroYDps: noise * 2,
        gyroZDps: noise * 1,
      );

  /// A rear-end collision: cruise, then a sharp deceleration spike.
  static const impactRearEnd = Scenario(
    id: 'impact-rear-end',
    name: 'Rear-end collision',
    description:
        'Vehicle cruises, then sustains an impact above the calibrated '
        'threshold. Confirms, offers a cancellation window, acquires GPS and '
        'transmits an alert.',
    duration: Duration(seconds: 14),
    samplesPerSecond: 20,
    gpsAvailable: true,
    gatewayAvailable: true,
    build: _buildImpact,
  );

  /// A harsh bump that stays under the threshold, so nothing is sent.
  static const falseAlarm = Scenario(
    id: 'false-alarm',
    name: 'Harsh bump (no alert)',
    description:
        'A sharp kerb strike that crosses the threshold briefly but falls back '
        'below it before the confirmation window closes. No packet is built.',
    duration: Duration(seconds: 12),
    samplesPerSecond: 20,
    build: _buildFalseAlarm,
  );

  /// A rollover.
  static const rollover = Scenario(
    id: 'rollover',
    name: 'Vehicle rollover',
    description:
        'The vehicle rotates onto its side. Rollover thresholds are crossed on '
        'both tilt and rotation rate.',
    duration: Duration(seconds: 12),
    samplesPerSecond: 20,
    build: _buildRollover,
  );

  /// An impact with no GPS fix: the packet is still sent, flagged.
  static const noGpsFix = Scenario(
    id: 'no-gps-fix',
    name: 'Impact with no GPS fix',
    description:
        'Demonstrates the documented alternate path: the alert is still '
        'transmitted, but the position is flagged as unavailable rather than '
        'omitted or invented.',
    duration: Duration(seconds: 12),
    samplesPerSecond: 20,
    gpsAvailable: false,
    build: _buildImpact,
  );

  /// An impact with no gateway coverage.
  static const noGateway = Scenario(
    id: 'no-gateway',
    name: 'Impact with no gateway in range',
    description:
        'The node transmits but nothing is acknowledged. The UI must show an '
        'unresolved delivery, not a success.',
    duration: Duration(seconds: 12),
    samplesPerSecond: 20,
    gatewayAvailable: false,
    expectedOutcome: TransmissionOutcome.noGatewayInRange,
    build: _buildImpact,
  );

  /// A calm drive that should never raise an event.
  static const normalDriving = Scenario(
    id: 'normal-driving',
    name: 'Normal driving',
    description:
        'Ordinary motion over uneven road surface. Stays below every threshold '
        'and produces no alert.',
    duration: Duration(seconds: 20),
    samplesPerSecond: 20,
    build: _buildCruise,
  );

  static const List<Scenario> all = <Scenario>[
    impactRearEnd,
    falseAlarm,
    rollover,
    noGpsFix,
    noGateway,
    normalDriving,
  ];

  static Scenario byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => impactRearEnd);

  static ImuSample _buildCruise(double t, DateTime at) =>
      _cruising(t, math.sin(t * 7) * 0.5);

  static ImuSample _buildImpact(double t, DateTime at) {
    final noise = math.sin(t * 11) * 0.4;
    // Cruise for the first 4 s, then the impact.
    if (t < 4.0) return _cruising(t, noise);

    final sinceImpact = t - 4.0;
    // Sharp rise, then a damped oscillation as the vehicle rebounds.
    final magnitude = 5.4 * math.exp(-sinceImpact / 1.4) +
        1.4 * math.exp(-sinceImpact / 0.5) * math.cos(sinceImpact * 9);

    return ImuSample(
      timestamp: at,
      accelXG: noise * 0.05,
      accelYG: math.sin(sinceImpact * 14) * 0.4,
      accelZG: math.max(0.15, magnitude),
      gyroXDps: noise * 3,
      gyroYDps: math.cos(sinceImpact * 12) * 6,
      gyroZDps: noise * 2,
    );
  }

  static ImuSample _buildFalseAlarm(double t, DateTime at) {
    final noise = math.sin(t * 7) * 0.5;
    if (t < 4.0) return _cruising(t, noise);

    // A single 200 ms spike: enough to cross the threshold, too short to be
    // confirmed.
    final sinceImpact = t - 4.0;
    if (sinceImpact > 0.2) return _cruising(t, noise);
    return ImuSample(
      timestamp: at,
      accelXG: 0,
      accelYG: 0,
      accelZG: 4.1,
      gyroXDps: 0,
      gyroYDps: 0,
      gyroZDps: 0,
    );
  }

  static ImuSample _buildRollover(double t, DateTime at) {
    final noise = math.sin(t * 7) * 0.5;
    if (t < 3.5) return _cruising(t, noise);

    final sinceRoll = t - 3.5;
    // Rotate from upright to fully on its side over about 1.2 s.
    final angle = math.min(90.0, sinceRoll / 1.2 * 90.0);
    final radians = angle * math.pi / 180.0;
    final spin = math.exp(-sinceRoll / 2.5) * 260;

    return ImuSample(
      timestamp: at,
      accelXG: math.sin(radians),
      accelYG: 0,
      accelZG: math.cos(radians),
      gyroXDps: spin,
      gyroYDps: noise * 2,
      gyroZDps: noise * 2,
    );
  }

  /// Exposed for tests: the position at a given elapsed second, or null when
  /// the scenario has no GPS.
  static GeoFix? fixFor(Scenario scenario, double elapsedSeconds) =>
      scenario.gpsAvailable ? _fix(elapsedSeconds) : null;
}