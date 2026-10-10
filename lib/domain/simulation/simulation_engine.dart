import 'dart:async';

import '../accident_detector.dart';
import '../hardware/transport.dart';
import '../models/imu.dart';
import '../models/lora.dart';
import 'scenario.dart';

/// The state of a scenario playback.
enum PlaybackState { idle, playing, paused, finished }

/// Drives a [Scenario] and feeds it through the real [AccidentDetector].
///
/// The important property of this class is that it does **not** reimplement
/// detection. It generates scripted samples and hands them to the same state
/// machine the real hardware path uses, so Demo Mode exercises production logic
/// instead of a parallel simulation of it.
class SimulationEngine {
  SimulationEngine({
    required this.detector,
    required this.transport,
    this.onSample,
    this.onProgress,
    this.onPacketTransmitted,
    this.onStageChanged,
  });

  final AccidentDetector detector;
  final PacketTransport transport;

  /// Fired for every generated sample. Callers use this to drive charts.
  final void Function(ImuSample sample)? onSample;

  /// Fired with 0..1 playback progress.
  final void Function(double progress)? onProgress;

  /// Fired once the simulated radio completes an attempt.
  final void Function(LoraPacket packet, TransmissionOutcome outcome)?
      onPacketTransmitted;

  final void Function(DetectionStage stage)? onStageChanged;

  Scenario _scenario = Scenarios.impactRearEnd;
  PlaybackState _state = PlaybackState.idle;
  Timer? _timer;
  DateTime? _wallStart;
  DateTime _epoch = DateTime(2026, 1, 1);
  Duration _elapsed = Duration.zero;
  double _speed = 1.0;
  int _lastStageIndex = -1;

  Scenario get scenario => _scenario;
  PlaybackState get state => _state;
  Duration get elapsed => _elapsed;

  /// Playback speed multiplier. Values are clamped to a sane range so the
  /// engine cannot be starved by an absurd value.
  double get speed => _speed;
  set speed(double value) => _speed = value.clamp(0.25, 4.0);

  double get progress {
    if (_scenario.duration.inMilliseconds == 0) return 0;
    return (_elapsed.inMilliseconds / _scenario.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// Loads [scenario] and resets the engine without starting playback.
  void load(Scenario scenario) {
    _timer?.cancel();
    _timer = null;
    // Re-arm so a new scenario can detect its own event even when the previous
    // run ended in a terminal stage.
    detector.arm();
    _scenario = scenario;
    _state = PlaybackState.idle;
    _elapsed = Duration.zero;
    _wallStart = null;
    _epoch = DateTime.now();
    _lastStageIndex = -1;
    detector.updateGps(null);
  }

  void play() {
    if (_state == PlaybackState.playing) return;
    if (_state == PlaybackState.finished) restart();

    // Resuming from a pause must continue from the current offset, so the
    // start reference is rebased rather than reset.
    _wallStart = DateTime.now().subtract(_elapsed);
    _state = PlaybackState.playing;

    const tick = Duration(milliseconds: 40);
    _timer = Timer.periodic(tick, (_) => _onTick(tick));
  }

  void pause() {
    if (_state != PlaybackState.playing) return;
    _timer?.cancel();
    _timer = null;
    _state = PlaybackState.paused;
  }

  void toggle() => _state == PlaybackState.playing ? pause() : play();

  /// Restarts the current scenario from the beginning.
  void restart() {
    _timer?.cancel();
    _timer = null;
    _elapsed = Duration.zero;
    _wallStart = null;
    _state = PlaybackState.idle;
    _lastStageIndex = -1;
    detector.updateGps(null);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _state = PlaybackState.idle;
    _elapsed = Duration.zero;
    _wallStart = null;
    _lastStageIndex = -1;
    detector.updateGps(null);
  }

  /// Steps scripted samples without a wall-clock timer.
  ///
  /// Used by tests to replay a scenario deterministically. When the steps carry
  /// the run past the scenario duration the run is finished, exactly as a
  /// wall-clock playback would be, so a stepped replay resolves identically to
  /// a watched one.
  Future<void> step({
    required int samples,
    required Duration sampleInterval,
  }) async {
    for (var i = 0; i < samples; i++) {
      if (_state == PlaybackState.finished) break;
      _elapsed += sampleInterval;
      if (_elapsed > _scenario.duration) {
        _elapsed = _scenario.duration;
      }

      _emitSample();
      // Advance the detector on the same synthetic clock the samples carry, so
      // timed windows elapse deterministically without any real waiting.
      detector.advance(_now);
      _emitStageChange();

      if (_elapsed >= _scenario.duration) {
        await _finish();
        return;
      }
    }
    onProgress?.call(progress);
  }

  /// The scenario's own clock. Samples, detector stages and packet timestamps
  /// all read from this single source, which is what makes a run reproducible.
  DateTime get _now => _epoch.add(_elapsed);

  void _onTick(Duration tick) {
    final started = _wallStart;
    if (started == null) return;

    // Advance by wall-clock so playback speed is honoured even if ticks are
    // late or the app was briefly backgrounded.
    _elapsed = DateTime.now().difference(started);

    if (_elapsed >= _scenario.duration) {
      _elapsed = _scenario.duration;
      _emitSample();
      unawaited(_finish());
      return;
    }

    _emitSample();
    _emitStageChange();
    onProgress?.call(progress);
  }

  void _emitStageChange() {
    final stageIndex = detector.stage.index;
    if (stageIndex == _lastStageIndex) return;
    _lastStageIndex = stageIndex;
    onStageChanged?.call(detector.stage);
  }

  void _emitSample() {
    final t = _elapsed.inMilliseconds / 1000.0;
    final sample = _scenario.build(t, _now);

    // Keep the simulated position in step with the scenario so the map panel
    // reflects the same run the detector is seeing.
    detector.updateGps(Scenarios.fixFor(_scenario, t));

    onSample?.call(sample);
    detector.ingest(sample);
  }

  Future<void> _finish() async {
    _timer?.cancel();
    _timer = null;
    _state = PlaybackState.finished;

    // Drive any remaining timed stages forward so the run resolves rather than
    // stopping part-way through a window.
    var guard = 0;
    while (detector.stage != DetectionStage.monitoring &&
        detector.stage != DetectionStage.transmitting &&
        detector.stage != DetectionStage.dispatched &&
        detector.stage != DetectionStage.failed &&
        guard < 400) {
      _elapsed += const Duration(milliseconds: 100);
      final future = _now.add(const Duration(milliseconds: 100));
      detector.advance(future);
      guard++;
    }

    final pending = detector.currentResult().packet;
    if (pending != null) {
      await _transmit(pending);
    }
    onProgress?.call(1);
  }

  /// Runs the simulated radio for [packet] and reports the outcome honestly
  /// against the scenario's declared gateway availability.
  Future<void> _transmit(LoraPacket packet) async {
    final outcome = _scenario.gatewayAvailable
        ? await transport.transmit(packet)
        : TransmissionOutcome.noGatewayInRange;

    detector.completeTransmission(
      packet,
      outcome,
      // Only a gateway acknowledgement counts as a confirmation.
      acknowledged: outcome == TransmissionOutcome.acknowledged,
    );
    onPacketTransmitted?.call(packet, outcome);
  }
}