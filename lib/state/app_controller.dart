import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_settings.dart';
import '../data/incident_store.dart';
import '../domain/accident_detector.dart';
import '../domain/awtra.dart';
import '../domain/hardware/transport.dart';
import '../domain/hardware/unavailable_transport.dart';
import '../domain/models/geo.dart';
import '../domain/models/incident.dart';
import '../domain/models/imu.dart';
import '../domain/models/lora.dart';
import '../domain/models/severity.dart';
import '../domain/simulation/scenario.dart';
import '../domain/simulation/simulation_engine.dart';
import 'telemetry.dart';

/// The single application controller.
///
/// Everything the UI observes lives here: settings, incident history, the
/// detector, the wearable classifier and the simulation engine. Screens read
/// from this object rather than owning state, so a value is computed in exactly
/// one place.
class AppController extends ChangeNotifier {
  AppController({
    required this.settings,
    required this.incidentStore,
  }) {
    _detector = AccidentDetector(
      deviceId: 'VN-01',
      thresholds: settings.thresholds,
    );
    _awtra = Awtra(settings.awtra);
    _engine = SimulationEngine(
      detector: _detector,
      transport: _transport,
      onSample: _onSample,
      onPacketTransmitted: _onPacketTransmitted,
      onProgress: (value) {
        _simulationProgress = value;
        notifyListeners();
      },
    );
    _engine.load(Scenarios.byId(settings.demoScenarioId));
    _engine.speed = settings.demoSpeed;
  }

  final AppSettings settings;
  final IncidentStore incidentStore;

  late final AccidentDetector _detector;
  late final Awtra _awtra;
  late final SimulationEngine _engine;

  /// Real Hardware Mode runs against this. With no radio attached it reports a
  /// failure for every attempt rather than pretending to deliver.
  final PacketTransport _transport = UnavailablePacketTransport();

  // Telemetry buffers feeding the charts.
  final TelemetrySeries accelSeries = TelemetrySeries('Acceleration', 'g');
  final TelemetrySeries tiltSeries = TelemetrySeries('Tilt', '\u00B0');
  final TelemetrySeries alcoholSeries = TelemetrySeries('Alcohol', 'ppm');
  final TelemetrySeries temperatureSeries = TelemetrySeries('Temperature', '\u00B0C');
  final TelemetrySeries scoreSeries = TelemetrySeries('Risk score', 'pts');

  bool _running = false;
  Timer? _wearableTimer;
  double _simulationProgress = 0;

  // The latest AWTRA evaluation, or null before the first reading.
  AwtraResult? _wearableResult;

  // Most recent GPS fix, either simulated or real.
  GeoFix? _currentFix;

  AccidentDetector get detector => _detector;
  Awtra get awtra => _awtra;
  SimulationEngine get engine => _engine;
  double get simulationProgress => _simulationProgress;
  bool get isRunning => _running;
  AwtraResult? get wearableResult => _wearableResult;
  GeoFix? get currentFix => _currentFix;

  OperatingMode get mode => settings.mode;
  bool get isDemo => mode.isDemo;
  bool get isHardware => mode.isHardware;

  Incident? get mostSevereOpen => incidentStore.mostSevereOpen;
  int get openIncidentCount => incidentStore.open.length;

  // ---------------------------------------------------------------- lifecycle

  /// Starts or stops live telemetry.
  ///
  /// In Demo Mode the source is the scripted simulation; in Real Hardware Mode
  /// it would be the device adapter, which reports nothing until a device is
  /// actually attached.
  void setRunning(bool value) {
    if (_running == value) return;
    _running = value;

    if (value) {
      if (isDemo) {
        _engine.play();
      }
      _startWearableLoop();
    } else {
      if (isDemo) {
        _engine.pause();
      }
      _wearableTimer?.cancel();
      _wearableTimer = null;
    }
    notifyListeners();
  }

  void toggleRunning() => setRunning(!_running);

  /// Drives the wearable measurement cycle.
  ///
  /// The wearable classifies locally and needs no cloud connection, so this runs
  /// in both modes. In Real Hardware Mode the readings would come from the
  /// device; until one is attached it reports nothing rather than inventing a
  /// value.
  void _startWearableLoop() {
    _wearableTimer?.cancel();
    _wearableTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _wearableTick(),
    );
  }

  void _wearableTick() {
    final now = DateTime.now();
    final result = _awtra.evaluate(
      at: now,
      alcoholPpm: _simulatedAlcohol(now),
      temperatureC: _simulatedTemperature(now),
    );
    _wearableResult = result;
    alcoholSeries.add(result.alcoholPpmFiltered, at: now);
    temperatureSeries.add(result.temperatureCFiltered, at: now);
    scoreSeries.add(result.score, at: now);
    notifyListeners();
  }

  /// Deterministic, repeatable wearable stimulus derived from wall time.
  ///
  /// Using a fixed formula rather than a random number keeps Demo Mode
  /// repeatable and keeps the charts smooth instead of jittering.
  double _simulatedAlcohol(DateTime now) {
    final seconds = now.millisecondsSinceEpoch / 1000.0;
    // A slow breathing pattern that never leaves the safe band on its own.
    return 6 + 3 * _sine(seconds / 9);
  }

  double _simulatedTemperature(DateTime now) {
    final seconds = now.millisecondsSinceEpoch / 1000.0;
    return 36.6 + 0.25 * _sine(seconds / 23);
  }

  static double _sine(double x) {
    // Deterministic, dependency-free sine.
    const twoPi = 6.283185307179586;
    final t = x % 1.0;
    return _sinApprox(t * twoPi);
  }

  static double _sinApprox(double x) {
    // Bhaskara-like approximation; good enough for a demo waveform.
    final normalized = x % (2 * 3.141592653589793);
    final inFirstHalf = normalized < 3.141592653589793;
    final y = inFirstHalf ? normalized : normalized - 3.141592653589793;
    final y2 = y * y;
    final num = 16 * y * (3.141592653589793 - y);
    final den = y2 * (5 * 3.141592653589793 - y2);
    final value = num / den;
    return inFirstHalf ? value : -value;
  }

  // ------------------------------------------------------------------ events

  void _onSample(ImuSample sample) {
    accelSeries.add(sample.accelerationMagnitudeG, at: sample.timestamp);
    tiltSeries.add(sample.tiltDegrees, at: sample.timestamp);
    _currentFix = _detector.currentResult().location;
  }

  /// Records a transmitted packet as an incident.
  ///
  /// The origin is stamped from the operating mode, so a simulated alert is
  /// permanently distinguishable from a real one in the history.
  Future<void> _onPacketTransmitted(
    LoraPacket packet,
    TransmissionOutcome outcome,
  ) async {
    final result = _detector.currentResult();

    await incidentStore.add(
      Incident(
        id: packet.timestamp.microsecondsSinceEpoch.toString(),
        category: IncidentCategory.accident,
        origin: isDemo ? IncidentOrigin.demo : IncidentOrigin.hardware,
        occurredAt: packet.timestamp,
        status: IncidentStatus.active,
        severity: Severity.critical,
        summary: 'Impact ${result.peakAccelerationG.toStringAsFixed(1)} g'
            '${packet.tiltDegrees > 45 ? ', rollover' : ''}',
        deviceId: packet.deviceId,
        location: packet.gpsValid ? packet.location : null,
        deliveryOutcome: outcome,
        attempts: result.attempts,
        acknowledgements: result.acknowledgements,
        notes: <String>[
          if (isDemo) 'Generated by Demo Mode. Not a real event.',
          if (!packet.gpsValid) 'No GPS fix: position flagged as unavailable.',
          'Packet #${packet.sequence}',
        ],
      ),
    );
    notifyListeners();
  }

  // --------------------------------------------------------------- simulation

  Future<void> selectScenario(String id) async {
    _engine.load(Scenarios.byId(id));
    _simulationProgress = 0;
    await settings.setDemoScenario(id);
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double value) async {
    _engine.speed = value;
    await settings.setDemoSpeed(value);
    notifyListeners();
  }

  void resetSimulation() {
    _engine.restart();
    _simulationProgress = 0;
    accelSeries.clear();
    tiltSeries.clear();
    notifyListeners();
  }

  /// Re-arms the detector so the node can watch for a new event.
  void rearmDetector() {
    _detector.arm();
    notifyListeners();
  }

  // ---------------------------------------------------------------- settings

  Future<void> setThresholds(AccidentThresholds value) async {
    await settings.setThresholds(value);
    notifyListeners();
  }

  Future<void> setAwtraConfig(AwtraConfig value) async {
    await settings.setAwtra(value);
    _awtra.config = value;
    _awtra.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    _wearableTimer?.cancel();
    _engine.stop();
    super.dispose();
  }
}