import 'dart:math' as math;

import 'models/geo.dart';
import 'models/imu.dart';
import 'models/lora.dart';
import 'moving_average.dart';

/// Calibrated detection parameters for the vehicle node.
///
/// These are **preliminary calibration values**, not universal crash-detection
/// standards. Per the project documentation they must be calibrated for each
/// vehicle before any field use, which is why they are only editable behind the
/// Advanced toggle and always accompanied by that warning.
class AccidentThresholds {
  const AccidentThresholds({
    this.impactG = 3.5,
    this.rolloverDegrees = 60,
    this.rotationDps = 220,
    this.confirmWindowMs = 1200,
    this.cancelWindowMs = 8000,
    this.gpsFixTimeoutMs = 15000,
    this.filterWindow = 3,
  });

  /// Peak acceleration magnitude, in g, that suggests an impact.
  final double impactG;

  /// Tilt from upright, in degrees, that suggests a rollover.
  final double rolloverDegrees;

  /// Rotation rate, in degrees per second, that supports a rollover verdict.
  final double rotationDps;

  /// How long a candidate event must persist before it is confirmed.
  final int confirmWindowMs;

  /// The manual cancellation window during which the driver can cancel a false
  /// alarm. No packet is built during this time.
  final int cancelWindowMs;

  /// How long to wait for a GPS fix before sending a flagged packet.
  final int gpsFixTimeoutMs;

  /// Samples per moving-average window used on the IMU stream.
  final int filterWindow;

  AccidentThresholds copyWith({
    double? impactG,
    double? rolloverDegrees,
    double? rotationDps,
    int? confirmWindowMs,
    int? cancelWindowMs,
    int? gpsFixTimeoutMs,
    int? filterWindow,
  }) {
    return AccidentThresholds(
      impactG: impactG ?? this.impactG,
      rolloverDegrees: rolloverDegrees ?? this.rolloverDegrees,
      rotationDps: rotationDps ?? this.rotationDps,
      confirmWindowMs: confirmWindowMs ?? this.confirmWindowMs,
      cancelWindowMs: cancelWindowMs ?? this.cancelWindowMs,
      gpsFixTimeoutMs: gpsFixTimeoutMs ?? this.gpsFixTimeoutMs,
      filterWindow: filterWindow ?? this.filterWindow,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'impactG': impactG,
        'rolloverDegrees': rolloverDegrees,
        'rotationDps': rotationDps,
        'confirmWindowMs': confirmWindowMs,
        'cancelWindowMs': cancelWindowMs,
        'gpsFixTimeoutMs': gpsFixTimeoutMs,
        'filterWindow': filterWindow,
      };

  static AccidentThresholds fromJson(Map<String, dynamic> json) =>
      AccidentThresholds(
        impactG: (json['impactG'] as num?)?.toDouble() ?? 3.5,
        rolloverDegrees:
            (json['rolloverDegrees'] as num?)?.toDouble() ?? 60,
        rotationDps: (json['rotationDps'] as num?)?.toDouble() ?? 220,
        confirmWindowMs: (json['confirmWindowMs'] as num?)?.toInt() ?? 1200,
        cancelWindowMs: (json['cancelWindowMs'] as num?)?.toInt() ?? 8000,
        gpsFixTimeoutMs:
            (json['gpsFixTimeoutMs'] as num?)?.toInt() ?? 15000,
        filterWindow: (json['filterWindow'] as num?)?.toInt() ?? 3,
      );
}

/// Which part of the documented detection flow the node is in.
///
/// The order matches the workflow in the project documentation: read motion,
/// detect a candidate, confirm over a window, activate the warning, offer a
/// manual cancellation window, acquire GPS, build and transmit, then let the
/// gateway forward to the backend.
enum DetectionStage {
  monitoring('Monitoring', 'Reading accelerometer and gyroscope data'),
  candidate('Candidate detected', 'Motion pattern crossed a threshold'),
  confirming('Confirming', 'Checking the event against calibrated thresholds'),
  warning('Warning active', 'Possible impact \u2014 cancel if false'),
  cancelling('Cancellation window', 'Waiting for the driver to cancel'),
  acquiringGps('Acquiring GPS fix', 'Capturing position and timestamp'),
  transmitting('Transmitting', 'Sending a compact packet over LoRa'),
  dispatched('Dispatched', 'Gateway received the packet'),
  failed('Failed', 'The event could not be delivered');

  const DetectionStage(this.label, this.description);

  final String label;
  final String description;

  /// True while the operator is expected to be able to act.
  bool get isActionable =>
      this == DetectionStage.warning ||
      this == DetectionStage.cancelling;

  bool get isTerminal =>
      this == DetectionStage.dispatched || this == DetectionStage.failed;

  bool get isBusy => !isTerminal && this != DetectionStage.monitoring;
}

/// The outcome of a completed detection cycle.
class DetectionResult {
  const DetectionResult({
    required this.detectedAt,
    required this.stage,
    required this.peakAccelerationG,
    required this.peakTiltDegrees,
    required this.cancelled,
    required this.packet,
    required this.outcome,
    required this.location,
    this.attempts = 0,
    this.acknowledgements = 0,
  });

  final DateTime detectedAt;

  /// Where the cycle ended up.
  final DetectionStage stage;

  final double peakAccelerationG;
  final double peakTiltDegrees;

  /// True when the driver used the manual cancellation window.
  final bool cancelled;

  /// The packet that was built, or null if the event was cancelled or failed
  /// before packet construction.
  final LoraPacket? packet;

  /// The last transmission outcome. Null when nothing was transmitted.
  final TransmissionOutcome? outcome;

  /// The position used, or null when no position was known.
  final GeoFix? location;

  /// Transmission attempts and confirmed acknowledgements are tracked
  /// separately and must never be conflated.
  final int attempts;
  final int acknowledgements;

  bool get wasDelivered => outcome?.isDelivered ?? false;
  bool get wasCancelled => cancelled;

  /// True when a packet went out but was never confirmed. The UI must surface
  /// this as an unresolved delivery, not as a success.
  bool get isUnresolvedDelivery =>
      outcome == TransmissionOutcome.sentUnacknowledged;

  bool get gpsWasFlagged =>
      packet != null && packet!.gpsValid == false;
}

/// Why a candidate event was raised.
enum DetectionReason {
  none('None'),
  impact('Impact above threshold'),
  rollover('Rollover above threshold'),
  impactAndRollover('Impact and rollover combined');

  const DetectionReason(this.label);

  final String label;
}

/// The vehicle-side accident detection state machine.
///
/// This mirrors the firmware logic: a pure, deterministic state machine driven
/// by two inputs, [ingest] for IMU samples and [advance] for elapsed time. It
/// performs no I/O of its own, which keeps it fully unit-testable and keeps
/// simulation and real-hardware paths on exactly the same code.
class AccidentDetector {
  AccidentDetector({
    required this.deviceId,
    AccidentThresholds thresholds = const AccidentThresholds(),
    this.onPacket,
  })  : thresholds = thresholds,
        _accelFilter = MovingAverage(thresholds.filterWindow),
        _tiltFilter = MovingAverage(thresholds.filterWindow),
        _rotationFilter = MovingAverage(thresholds.filterWindow);

  final String deviceId;
  final AccidentThresholds thresholds;

  /// Called when a packet is ready to transmit. The host supplies the radio.
  final void Function(LoraPacket packet)? onPacket;

  final MovingAverage _accelFilter;
  final MovingAverage _tiltFilter;
  final MovingAverage _rotationFilter;

  DetectionStage _stage = DetectionStage.monitoring;
  DetectionReason _reason = DetectionReason.none;

  DateTime? _candidateSince;
  DateTime? _warningSince;
  DateTime _stageEnteredAt = DateTime.fromMillisecondsSinceEpoch(0);

  double _peakAccelG = 0;
  double _peakTiltDegrees = 0;
  double _peakRotationDps = 0;
  DateTime? _lastIngest;

  GeoFix? _fix;
  int _sequence = 0;
  int _attempts = 0;
  int _acknowledgements = 0;
  TransmissionOutcome? _outcome;
  LoraPacket? _packet;

  DetectionStage get stage => _stage;
  DetectionReason get reason => _reason;

  /// Elapsed milliseconds in the cancellation window, or null when not in it.
  Duration? get cancellationRemaining {
    if (_stage != DetectionStage.cancelling || _warningSince == null) {
      return null;
    }
    final elapsed = DateTime.now().difference(_warningSince!);
    final remaining =
        Duration(milliseconds: thresholds.cancelWindowMs) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Progress through the confirmation window, 0..1. Drives the progress
  /// indicator shown during candidate/confirming.
  double get confirmProgress {
    if (_stage != DetectionStage.confirming || _candidateSince == null) {
      return 0;
    }
    final elapsed =
        DateTime.now().difference(_candidateSince!).inMilliseconds;
    return (elapsed / thresholds.confirmWindowMs).clamp(0.0, 1.0);
  }

  /// Progress through the cancellation window, 0..1.
  double get cancelProgress {
    if (_stage != DetectionStage.cancelling || _warningSince == null) {
      return 0;
    }
    final elapsed = DateTime.now().difference(_warningSince!).inMilliseconds;
    return (elapsed / thresholds.cancelWindowMs).clamp(0.0, 1.0);
  }

  /// The most recent filtered view of the IMU stream, for display.
  ImuSnapshot? get snapshot {
    final last = _lastIngest;
    if (last == null) return null;
    return ImuSnapshot(
      sample: ImuSample.rest(last),
      accelerationMagnitudeG: _accelFilter.average,
      rotationMagnitudeDps: _rotationFilter.average,
      tiltDegrees: _tiltFilter.average,
    );
  }

  /// Supplies the current GPS fix. A null value means no fix is available.
  void updateGps(GeoFix? fix) => _fix = fix;

  /// Feeds one IMU sample. Samples must arrive in chronological order.
  void ingest(ImuSample sample) {
    _lastIngest = sample.timestamp;

    // Once a packet has been transmitted we stop thresholding: we do not want a
    // single crash to raise several overlapping alerts.
    if (_stage.isTerminal) return;

    _accelFilter.add(sample.accelerationMagnitudeG);
    _tiltFilter.add(sample.tiltDegrees);
    _rotationFilter.add(sample.rotationMagnitudeDps);

    final accel = _accelFilter.average;
    final tilt = _tiltFilter.average;
    final rotation = _rotationFilter.average;

    // Track the peak regardless of stage so the final report describes the
    // strongest part of the event.
    _peakAccelG = math.max(_peakAccelG, sample.accelerationMagnitudeG);
    _peakTiltDegrees = math.max(_peakTiltDegrees, sample.tiltDegrees);
    _peakRotationDps = math.max(_peakRotationDps, sample.rotationMagnitudeDps);

    final impactCrossed = accel >= thresholds.impactG;
    final rolloverCrossed = tilt >= thresholds.rolloverDegrees ||
        rotation >= thresholds.rotationDps;

    switch (_stage) {
      case DetectionStage.monitoring:
        if (impactCrossed || rolloverCrossed) {
          _reason = _classify(impactCrossed, rolloverCrossed);
          _candidateSince = sample.timestamp;
          _enter(DetectionStage.candidate, sample.timestamp);
        }
      case DetectionStage.candidate:
        // The stage marker is informational; confirmation is decided in
        // advance() once the window has elapsed with the event still present.
        if (!impactCrossed && !rolloverCrossed) {
          // The event fell back below threshold: a bump, not a crash.
          _resetToMonitoring();
        }
      case DetectionStage.confirming:
      case DetectionStage.warning:
      case DetectionStage.cancelling:
      case DetectionStage.acquiringGps:
      case DetectionStage.transmitting:
      case DetectionStage.dispatched:
      case DetectionStage.failed:
        return;
    }
  }

  /// Advances the timed stages. [now] is injected so tests can run
  /// deterministically without waiting on the wall clock.
  void advance(DateTime now) {
    switch (_stage) {
      case DetectionStage.candidate:
      case DetectionStage.confirming:
        final since = _candidateSince;
        if (since == null) return;
        final elapsed = now.difference(since).inMilliseconds;
        if (elapsed >= thresholds.confirmWindowMs) {
          _warningSince = now;
          _enter(DetectionStage.warning, now);
          // The warning stage immediately opens the cancellation window, which
          // is the documented behaviour: activate a warning, then let the
          // driver cancel a false alarm.
          _enter(DetectionStage.cancelling, now);
        }
      case DetectionStage.cancelling:
        final since = _warningSince;
        if (since == null) return;
        if (now.difference(since).inMilliseconds >= thresholds.cancelWindowMs) {
          _enter(DetectionStage.acquiringGps, now);
        }
      case DetectionStage.acquiringGps:
        _maybeLeaveGpsStage(now);
      case DetectionStage.warning:
        // The warning stage exists for one display frame only; advance() opens
        // the cancellation window immediately.
        return;
      case DetectionStage.monitoring:
      case DetectionStage.transmitting:
      case DetectionStage.dispatched:
      case DetectionStage.failed:
        return;
    }
  }

  /// The driver cancelled a false alarm. Only honoured during the cancellation
  /// window; calling it at any other time is ignored and reported as false.
  bool cancelEvent() {
    if (_stage != DetectionStage.cancelling) return false;
    _packet = null;
    _outcome = null;
    _resetToMonitoring();
    return true;
  }

  /// Reports the result of the transmission that the host performed.
  ///
  /// Kept separate from [advance] so that a "sent" packet and a confirmed
  /// acknowledgement remain distinct facts.
  void completeTransmission(
    LoraPacket packet,
    TransmissionOutcome outcome, {
    required bool acknowledged,
  }) {
    _packet = packet;
    _outcome = outcome;
    _attempts++;
    if (acknowledged) {
      _acknowledgements++;
      _enter(DetectionStage.dispatched, DateTime.now());
    } else if (outcome == TransmissionOutcome.sentUnacknowledged) {
      // Ambiguous: the packet may still be in flight. Stay visible rather than
      // claiming success or declaring failure.
      _enter(DetectionStage.transmitting, DateTime.now());
    } else {
      _enter(DetectionStage.failed, DateTime.now());
    }
  }

  /// Builds and emits the packet for a confirmed event. Called by the host once
  /// a position has been obtained or the GPS timeout has elapsed.
  LoraPacket buildPacket(DateTime now) {
    final fix = _fix;
    _sequence++;

    final packet = LoraPacket(
      sequence: _sequence,
      deviceId: deviceId,
      type: LoraEventType.accident,
      timestamp: _warningSince ?? now,
      accelerationG: _peakAccelG,
      tiltDegrees: _peakTiltDegrees,
      batteryPercent: 100,
      // With no fix we still transmit, flagged, so the backend knows the
      // position is unreliable rather than silently absent.
      gpsValid: fix != null,
      location: fix,
      sequenceOfRetries: _attempts,
    );

    _packet = packet;
    _attempts++;
    _enter(DetectionStage.transmitting, now);
    onPacket?.call(packet);
    return packet;
  }

  /// The detection that produced [packet], for handing to the incident store.
  DetectionResult resultFor(LoraPacket packet, TransmissionOutcome outcome,
      {bool acknowledged = false}) {
    return DetectionResult(
      detectedAt: _warningSince ?? packet.timestamp,
      stage: _stage,
      peakAccelerationG: _peakAccelG,
      peakTiltDegrees: _peakTiltDegrees,
      cancelled: false,
      packet: packet,
      outcome: outcome,
      location: _fix,
      attempts: _attempts,
      acknowledgements: _acknowledgements,
    );
  }

  /// The result of the cycle that just finished, for UI feedback.
  DetectionResult currentResult() => DetectionResult(
        detectedAt: _warningSince ?? DateTime.now(),
        stage: _stage,
        peakAccelerationG: _peakAccelG,
        peakTiltDegrees: _peakTiltDegrees,
        cancelled: _stage == DetectionStage.monitoring && _packet == null,
        packet: _packet,
        outcome: _outcome,
        location: _fix,
        attempts: _attempts,
        acknowledgements: _acknowledgements,
      );

  /// True when the node would send a packet right now.
  bool get isPacketPending => _stage == DetectionStage.transmitting;

  /// Re-arms the node for a new event.
  ///
  /// A terminal stage (dispatched or failed) deliberately stops further
  /// thresholding so a single crash cannot raise overlapping alerts. The node
  /// must then be re-armed before it will watch for the next event, which is
  /// what this does. The packet sequence number is intentionally preserved so
  /// a receiver can tell successive alerts apart.
  void arm() {
    if (!_stage.isTerminal) return;
    _resetToMonitoring();
    _packet = null;
    _outcome = null;
    _stageEnteredAt = DateTime.now();
  }

  void _maybeLeaveGpsStage(DateTime now) {
    // A fix arrived, or the timeout expired. Either way we transmit: without a
    // fix the packet is sent flagged rather than withheld.
    final timedOut = now
            .difference(_stageEnteredAt)
            .inMilliseconds >=
        thresholds.gpsFixTimeoutMs;
    if (_fix != null || timedOut) {
      buildPacket(now);
    }
  }

  void _resetToMonitoring() {
    _stage = DetectionStage.monitoring;
    _reason = DetectionReason.none;
    _candidateSince = null;
    _warningSince = null;
    _peakAccelG = 0;
    _peakTiltDegrees = 0;
    _peakRotationDps = 0;
    _accelFilter.clear();
    _tiltFilter.clear();
    _rotationFilter.clear();
  }

  void _enter(DetectionStage stage, DateTime at) {
    _stage = stage;
    _stageEnteredAt = at;
  }

  static DetectionReason _classify(bool impact, bool rollover) {
    if (impact && rollover) return DetectionReason.impactAndRollover;
    if (impact) return DetectionReason.impact;
    return DetectionReason.rollover;
  }
}