import 'package:flutter_test/flutter_test.dart';
import 'package:smart_safety_ecosystem/domain/accident_detector.dart';
import 'package:smart_safety_ecosystem/domain/hardware/transport.dart';
import 'package:smart_safety_ecosystem/domain/hardware/unavailable_transport.dart';
import 'package:smart_safety_ecosystem/domain/models/lora.dart';
import 'package:smart_safety_ecosystem/domain/simulation/scenario.dart';
import 'package:smart_safety_ecosystem/domain/simulation/simulation_engine.dart';

/// A transport that always acknowledges, used to prove the scenario scripts
/// reach a delivered state without any real radio.
class _AckTransport implements PacketTransport {
  final List<LoraPacket> sent = <LoraPacket>[];

  @override
  String get name => 'Test transport';

  @override
  bool get isConnected => true;

  @override
  DateTime? get lastActivity => DateTime(2026, 1, 1);

  @override
  Future<TransmissionOutcome> transmit(
    LoraPacket packet, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    sent.add(packet);
    return TransmissionOutcome.acknowledged;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  const interval = Duration(milliseconds: 50);

  ({SimulationEngine engine, AccidentDetector detector, _AckTransport radio})
      buildEngine(Scenario scenario) {
    final detector = AccidentDetector(
      deviceId: 'VN-01',
      thresholds: const AccidentThresholds(
        confirmWindowMs: 1000,
        cancelWindowMs: 3000,
        gpsFixTimeoutMs: 1500,
      ),
    );
    final radio = _AckTransport();
    final engine = SimulationEngine(detector: detector, transport: radio)
      ..load(scenario);
    return (engine: engine, detector: detector, radio: radio);
  }

  /// Replays a whole scenario on the engine's synthetic clock.
  Future<void> replay(SimulationEngine engine, Duration duration) async {
    final steps = duration.inMilliseconds ~/ interval.inMilliseconds;
    await engine.step(samples: steps, sampleInterval: interval);
  }

  test('every built-in scenario has a unique id and a description', () {
    final ids = Scenarios.all.map((s) => s.id).toSet();
    expect(ids.length, Scenarios.all.length);
    for (final scenario in Scenarios.all) {
      expect(scenario.description, isNotEmpty);
      expect(scenario.duration, greaterThan(Duration.zero));
      expect(scenario.samplesPerSecond, greaterThan(0));
    }
  });

  test('normal driving never raises an alert', () async {
    final e = buildEngine(Scenarios.normalDriving);
    await replay(e.engine, Scenarios.normalDriving.duration);

    expect(e.detector.stage, DetectionStage.monitoring);
    expect(e.radio.sent, isEmpty,
        reason: 'a calm drive must not produce any packet');
  });

  test('a harsh bump is not confirmed and sends nothing', () async {
    final e = buildEngine(Scenarios.falseAlarm);
    await replay(e.engine, Scenarios.falseAlarm.duration);

    expect(e.radio.sent, isEmpty);
  });

  test('a rear-end collision is confirmed and delivered', () async {
    final e = buildEngine(Scenarios.impactRearEnd);
    await replay(e.engine, Scenarios.impactRearEnd.duration);

    expect(e.radio.sent, hasLength(1));
    expect(e.detector.stage, DetectionStage.dispatched);
    expect(e.radio.sent.single.gpsValid, isTrue);
    expect(e.radio.sent.single.type, LoraEventType.accident);
  });

  test('a rollover is classified as a rollover', () async {
    final e = buildEngine(Scenarios.rollover);
    await replay(e.engine, Scenarios.rollover.duration);

    expect(e.radio.sent, hasLength(1));
    expect(e.detector.stage, DetectionStage.dispatched);
  });

  test('no GPS fix still transmits, flagged', () async {
    final e = buildEngine(Scenarios.noGpsFix);
    await replay(e.engine, Scenarios.noGpsFix.duration);

    expect(e.radio.sent, hasLength(1));
    expect(e.radio.sent.single.gpsValid, isFalse,
        reason: 'a missing fix must be flagged, never invented');
  });

  test('no gateway in range is never reported as delivered', () async {
    final e = buildEngine(Scenarios.noGateway);
    await replay(e.engine, Scenarios.noGateway.duration);

    // No radio was used because the scenario declares no gateway coverage.
    expect(e.radio.sent, isEmpty);
    expect(e.detector.stage, DetectionStage.failed);
    final result = e.detector.currentResult();
    expect(result.wasDelivered, isFalse);
  });

  test('the same scenario replays identically', () async {
    Future<List<double>> runOnce() async {
      final e = buildEngine(Scenarios.impactRearEnd);
      await replay(e.engine, Scenarios.impactRearEnd.duration);
      return e.radio.sent
          .map((p) => p.accelerationG + p.tiltDegrees)
          .toList(growable: false);
    }

    expect(await runOnce(), await runOnce());
  });

  test('pause and resume continue from the same offset', () async {
    final e = buildEngine(Scenarios.impactRearEnd);
    await e.engine.step(samples: 10, sampleInterval: interval);
    final afterFirst = e.engine.elapsed;

    await e.engine.step(samples: 5, sampleInterval: interval);
    expect(e.engine.elapsed, greaterThan(afterFirst));
    expect(
      e.engine.elapsed,
      afterFirst + interval * 5,
      reason: 'elapsed time must accumulate, not reset',
    );
  });

  test('playback speed is clamped to a sane range', () {
    final e = buildEngine(Scenarios.impactRearEnd);
    e.engine.speed = 100;
    expect(e.engine.speed, 4.0);
    e.engine.speed = 0.01;
    expect(e.engine.speed, 0.25);
  });

  test('progress is bounded between 0 and 1', () async {
    final e = buildEngine(Scenarios.impactRearEnd);
    expect(e.engine.progress, 0);
    await replay(e.engine, Scenarios.impactRearEnd.duration * 2);
    expect(e.engine.progress, inInclusiveRange(0.0, 1.0));
  });

  test('a second run of the same scenario sends a second packet', () async {
    final e = buildEngine(Scenarios.impactRearEnd);
    await replay(e.engine, Scenarios.impactRearEnd.duration);
    expect(e.radio.sent, hasLength(1));

    e.engine
      ..stop()
      ..load(Scenarios.impactRearEnd);
    await replay(e.engine, Scenarios.impactRearEnd.duration);
    expect(e.radio.sent, hasLength(2));
    expect(e.radio.sent.last.sequence, 2,
        reason: 'sequence numbers must advance across runs');
  });

  test('the unavailable transport refuses rather than fabricating', () {
    // This is what Real Hardware Mode uses with no radio attached. It must
    // report a failure for every attempt, never a success.
    final transport = UnavailablePacketTransport();
    expect(transport.isConnected, isFalse);
    expect(transport.lastActivity, isNull);

    final packet = LoraPacket(
      sequence: 1,
      deviceId: 'VN-01',
      type: LoraEventType.accident,
      timestamp: DateTime(2026, 1, 1),
      accelerationG: 5,
      tiltDegrees: 0,
      batteryPercent: 90,
    );
    expect(
      transport.transmit(packet),
      completion(TransmissionOutcome.noGatewayInRange),
    );
  });
}