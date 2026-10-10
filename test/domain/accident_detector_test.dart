import 'package:flutter_test/flutter_test.dart';
import 'package:smart_safety_ecosystem/domain/accident_detector.dart';
import 'package:smart_safety_ecosystem/domain/models/geo.dart';
import 'package:smart_safety_ecosystem/domain/models/imu.dart';
import 'package:smart_safety_ecosystem/domain/models/lora.dart';

void main() {
  const thresholds = AccidentThresholds(
    impactG: 3.5,
    rolloverDegrees: 60,
    rotationDps: 220,
    confirmWindowMs: 1000,
    cancelWindowMs: 5000,
    gpsFixTimeoutMs: 2000,
  );

  final base = DateTime(2026, 3, 1, 10);

  AccidentDetector newDetector({void Function(LoraPacket)? onPacket}) =>
      AccidentDetector(
        deviceId: 'VN-01',
        thresholds: thresholds,
        onPacket: onPacket,
      );

  /// Feeds rest samples, then a sustained impact, starting at [start].
  void feedImpact(
    AccidentDetector detector,
    DateTime start, {
    int count = 6,
    double peakG = 5.0,
  }) {
    var t = start;
    for (var i = 0; i < count; i++) {
      detector.ingest(ImuSample.rest(t));
      t = t.add(const Duration(milliseconds: 40));
    }
    for (var i = 0; i < count; i++) {
      detector.ingest(
        ImuSample(
          timestamp: t,
          accelXG: 0,
          accelYG: 0,
          accelZG: peakG,
          gyroXDps: 10,
          gyroYDps: 10,
          gyroZDps: 10,
        ),
      );
      t = t.add(const Duration(milliseconds: 40));
    }
  }

  /// Absolute stage boundaries for a crash started at [from].
  DateTime confirmedAt(DateTime from) =>
      from.add(const Duration(milliseconds: 1500));
  DateTime cancelledAt(DateTime from) =>
      confirmedAt(from).add(const Duration(milliseconds: 5000));

  /// Drives a detector through impact, confirmation, an expired cancellation
  /// window and a successful GPS fix, returning the transmitted packet.
  LoraPacket driveToTransmit(
    AccidentDetector detector,
    DateTime from, {
    double peakG = 5.0,
  }) {
    feedImpact(detector, from, peakG: peakG);
    detector.advance(confirmedAt(from));
    expect(detector.stage, DetectionStage.cancelling);

    detector.advance(cancelledAt(from));
    expect(detector.stage, DetectionStage.acquiringGps);

    detector.updateGps(
      GeoFix(latitude: 12.9716, longitude: 77.5946, fixedAt: cancelledAt(from)),
    );
    detector.advance(cancelledAt(from).add(const Duration(milliseconds: 200)));
    expect(detector.stage, DetectionStage.transmitting);
    return detector.currentResult().packet!;
  }

  test('starts in monitoring', () {
    final detector = newDetector();
    expect(detector.stage, DetectionStage.monitoring);
    expect(detector.reason, DetectionReason.none);
  });

  test('a smooth ride never leaves monitoring', () {
    final detector = newDetector();
    var t = base;
    for (var i = 0; i < 100; i++) {
      detector
        ..ingest(ImuSample.rest(t))
        ..advance(t);
      t = t.add(const Duration(milliseconds: 40));
    }
    expect(detector.stage, DetectionStage.monitoring);
    expect(detector.reason, DetectionReason.none);
  });

  test('a bump that falls back below threshold is not confirmed', () {
    final detector = newDetector();
    var t = base;

    // One sharp spike, then a return to normal.
    detector.ingest(
      ImuSample(
        timestamp: t,
        accelXG: 0,
        accelYG: 0,
        accelZG: 6,
        gyroXDps: 0,
        gyroYDps: 0,
        gyroZDps: 0,
      ),
    );
    t = t.add(const Duration(milliseconds: 60));
    for (var i = 0; i < 10; i++) {
      detector
        ..ingest(ImuSample.rest(t))
        ..advance(t);
      t = t.add(const Duration(milliseconds: 40));
    }

    expect(detector.stage, DetectionStage.monitoring);
  });

  test('a sustained impact opens the cancellation window', () {
    final detector = newDetector();
    feedImpact(detector, base);
    detector.advance(confirmedAt(base));

    expect(detector.stage, DetectionStage.cancelling);
    expect(detector.reason, DetectionReason.impact);
  });

  test('rollover is classified separately from impact', () {
    final detector = newDetector();
    var t = base;
    for (var i = 0; i < 6; i++) {
      // Gravity now along x: the device is on its side, spinning.
      detector.ingest(
        ImuSample(
          timestamp: t,
          accelXG: 0.98,
          accelYG: 0,
          accelZG: 0.1,
          gyroXDps: 260,
          gyroYDps: 0,
          gyroZDps: 0,
        ),
      );
      t = t.add(const Duration(milliseconds: 40));
    }
    detector.advance(confirmedAt(base));

    expect(detector.stage, DetectionStage.cancelling);
    expect(detector.reason, DetectionReason.rollover);
  });

  test('cancelling during the window returns to monitoring', () {
    final detector = newDetector();
    feedImpact(detector, base);
    detector.advance(confirmedAt(base));

    expect(detector.stage, DetectionStage.cancelling);
    expect(detector.cancelEvent(), isTrue);
    expect(detector.stage, DetectionStage.monitoring);
    expect(
      detector.cancelEvent(),
      isFalse,
      reason: 'cancelling outside the window must be refused',
    );
  });

  test('an uncancelled event acquires GPS and builds a packet', () {
    driveToTransmit(newDetector(), base);
  });

  test('the packet carries the peak values and a valid fix', () {
    LoraPacket? captured;
    final detector = newDetector(onPacket: (packet) => captured = packet);

    driveToTransmit(detector, base, peakG: 5.0);

    expect(captured, isNotNull);
    expect(captured!.deviceId, 'VN-01');
    expect(captured!.gpsValid, isTrue);
    expect(captured!.type, LoraEventType.accident);
    expect(captured!.accelerationG, 5.0);
    // The impact is purely vertical (gravity still along z), so the vehicle is
    // upright: tilt must stay at 0 and must not be confused with a rollover.
    expect(captured!.tiltDegrees, 0);
    expect(captured!.toHex(), isNotEmpty);
  });

  test('no GPS fix produces a flagged packet, not a dropped alert', () {
    final detector = newDetector();
    feedImpact(detector, base);
    detector.advance(confirmedAt(base));
    detector.advance(cancelledAt(base));
    expect(detector.stage, DetectionStage.acquiringGps);

    // No fix arrives; after the timeout the packet is still sent, flagged.
    detector.advance(
      cancelledAt(base).add(const Duration(milliseconds: 2500)),
    );

    expect(detector.stage, DetectionStage.transmitting);
    expect(detector.currentResult().gpsWasFlagged, isTrue);
  });

  test('an acknowledged packet dispatches', () {
    final detector = newDetector();
    final packet = driveToTransmit(detector, base);

    detector.completeTransmission(
      packet,
      TransmissionOutcome.acknowledged,
      acknowledged: true,
    );

    expect(detector.stage, DetectionStage.dispatched);
    final result = detector.currentResult();
    expect(result.wasDelivered, isTrue);
    expect(result.acknowledgements, 1);
  });

  test('a sent-but-unacknowledged packet is not reported as delivered', () {
    final detector = newDetector();
    final packet = driveToTransmit(detector, base);

    detector.completeTransmission(
      packet,
      TransmissionOutcome.sentUnacknowledged,
      acknowledged: false,
    );

    final result = detector.currentResult();
    expect(result.wasDelivered, isFalse);
    expect(
      result.isUnresolvedDelivery,
      isTrue,
      reason: '"sent" must never be presented as "delivered"',
    );
  });

  test('a failed transmission is not a delivery', () {
    final detector = newDetector();
    final packet = driveToTransmit(detector, base);

    detector.completeTransmission(
      packet,
      TransmissionOutcome.noGatewayInRange,
      acknowledged: false,
    );

    expect(detector.stage, DetectionStage.failed);
    expect(detector.currentResult().wasDelivered, isFalse);
  });

  test('attempts and acknowledgements are counted separately', () {
    final detector = newDetector();
    final packet = driveToTransmit(detector, base);

    detector.completeTransmission(
      packet,
      TransmissionOutcome.sentUnacknowledged,
      acknowledged: false,
    );

    final result = detector.currentResult();
    expect(result.attempts, greaterThan(result.acknowledgements));
    expect(result.acknowledgements, 0);
  });

  test('a terminal event stops raising overlapping alerts', () {
    final detector = newDetector();
    final packet = driveToTransmit(detector, base);
    detector.completeTransmission(
      packet,
      TransmissionOutcome.acknowledged,
      acknowledged: true,
    );

    // A second, harder crash after the first was dispatched.
    detector.ingest(
      ImuSample(
        timestamp: base.add(const Duration(seconds: 30)),
        accelXG: 0,
        accelYG: 0,
        accelZG: 9,
        gyroXDps: 0,
        gyroYDps: 0,
        gyroZDps: 0,
      ),
    );

    expect(detector.stage, DetectionStage.dispatched);
  });

  test('confirmation and cancellation progress stay in range', () {
    final detector = newDetector();
    feedImpact(detector, base);
    expect(detector.confirmProgress, inInclusiveRange(0.0, 1.0));

    detector.advance(confirmedAt(base));
    expect(detector.stage, DetectionStage.cancelling);
    expect(detector.cancelProgress, inInclusiveRange(0.0, 1.0));
  });

  test('thresholds round-trip through JSON', () {
    const original = AccidentThresholds(
      impactG: 4.2,
      rolloverDegrees: 55,
      confirmWindowMs: 1500,
      cancelWindowMs: 9000,
    );
    final restored = AccidentThresholds.fromJson(original.toJson());

    expect(restored.impactG, 4.2);
    expect(restored.rolloverDegrees, 55);
    expect(restored.confirmWindowMs, 1500);
    expect(restored.cancelWindowMs, 9000);
  });
}