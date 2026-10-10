import 'dart:math' as math;

import 'moving_average.dart';
import 'models/severity.dart';

/// The three status bands documented for AWTRA.
enum RiskBand {
  safe('Safe', '0 \u2013 39', 'No action required', Severity.safe),
  medium('Medium risk', '40 \u2013 79', 'Review before proceeding', Severity.caution),
  high('High risk', '80 \u2013 100', 'Refer for assessment', Severity.critical);

  const RiskBand(this.label, this.range, this.action, this.severity);

  final String label;
  final String range;

  /// Plain-language next step shown to the operator.
  final String action;
  final Severity severity;

  static RiskBand fromScore(double score) {
    if (score >= 80) return RiskBand.high;
    if (score >= 40) return RiskBand.medium;
    return RiskBand.safe;
  }
}

/// Tunable AWTRA parameters.
///
/// Every value here is a *prototype* calibration, matching the project notes
/// which state these are preliminary values requiring calibration and
/// validation. They are editable only behind the Advanced toggle, and the UI
/// always shows their effect before saving.
class AwtraConfig {
  const AwtraConfig({
    this.alcoholWeight = 0.7,
    this.alcoholCautionPpm = 40,
    this.alcoholHighPpm = 120,
    this.alcoholCautionScore = 40,
    this.alcoholHighScore = 100,
    this.temperatureLowC = 35.0,
    this.temperatureCautionC = 37.5,
    this.temperatureHighC = 38.5,
    this.temperatureCautionScore = 40,
    this.temperatureHighScore = 100,
    this.filterWindow = 8,
    this.temperatureAmbientFloorC = 12,
    this.temperatureAmbientCeilingC = 45,
  });

  /// Share of the total score contributed by the alcohol channel. The
  /// temperature weight is `1 - alcoholWeight`.
  final double alcoholWeight;

  /// MQ-3 concentration in ppm at which the alcohol channel begins to score,
  /// and at which it saturates.
  final double alcoholCautionPpm;
  final double alcoholHighPpm;
  final double alcoholCautionScore;
  final double alcoholHighScore;

  /// Below [temperatureLowC] is treated as abnormally low; above
  /// [temperatureCautionC] is a caution; above [temperatureHighC] saturates.
  final double temperatureLowC;
  final double temperatureCautionC;
  final double temperatureHighC;
  final double temperatureCautionScore;
  final double temperatureHighScore;

  /// Number of samples in each moving-average window.
  final int filterWindow;

  /// Plausibility bounds. Readings outside these are treated as sensor faults
  /// rather than as extreme medical or alcohol values, which keeps a faulty
  /// probe from producing a false high-risk result.
  final double temperatureAmbientFloorC;
  final double temperatureAmbientCeilingC;

  AwtraConfig copyWith({
    double? alcoholWeight,
    double? alcoholCautionPpm,
    double? alcoholHighPpm,
    double? alcoholCautionScore,
    double? alcoholHighScore,
    double? temperatureLowC,
    double? temperatureCautionC,
    double? temperatureHighC,
    double? temperatureCautionScore,
    double? temperatureHighScore,
    int? filterWindow,
    double? temperatureAmbientFloorC,
    double? temperatureAmbientCeilingC,
  }) {
    return AwtraConfig(
      alcoholWeight: alcoholWeight ?? this.alcoholWeight,
      alcoholCautionPpm: alcoholCautionPpm ?? this.alcoholCautionPpm,
      alcoholHighPpm: alcoholHighPpm ?? this.alcoholHighPpm,
      alcoholCautionScore: alcoholCautionScore ?? this.alcoholCautionScore,
      alcoholHighScore: alcoholHighScore ?? this.alcoholHighScore,
      temperatureLowC: temperatureLowC ?? this.temperatureLowC,
      temperatureCautionC: temperatureCautionC ?? this.temperatureCautionC,
      temperatureHighC: temperatureHighC ?? this.temperatureHighC,
      temperatureCautionScore:
          temperatureCautionScore ?? this.temperatureCautionScore,
      temperatureHighScore:
          temperatureHighScore ?? this.temperatureHighScore,
      filterWindow: filterWindow ?? this.filterWindow,
      temperatureAmbientFloorC:
          temperatureAmbientFloorC ?? this.temperatureAmbientFloorC,
      temperatureAmbientCeilingC:
          temperatureAmbientCeilingC ?? this.temperatureAmbientCeilingC,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'alcoholWeight': alcoholWeight,
        'alcoholCautionPpm': alcoholCautionPpm,
        'alcoholHighPpm': alcoholHighPpm,
        'alcoholCautionScore': alcoholCautionScore,
        'alcoholHighScore': alcoholHighScore,
        'temperatureLowC': temperatureLowC,
        'temperatureCautionC': temperatureCautionC,
        'temperatureHighC': temperatureHighC,
        'temperatureCautionScore': temperatureCautionScore,
        'temperatureHighScore': temperatureHighScore,
        'filterWindow': filterWindow,
        'temperatureAmbientFloorC': temperatureAmbientFloorC,
        'temperatureAmbientCeilingC': temperatureAmbientCeilingC,
      };

  static AwtraConfig fromJson(Map<String, dynamic> json) {
    double d(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;

    return AwtraConfig(
      alcoholWeight: d('alcoholWeight', 0.6),
      alcoholCautionPpm: d('alcoholCautionPpm', 40),
      alcoholHighPpm: d('alcoholHighPpm', 120),
      alcoholCautionScore: d('alcoholCautionScore', 40),
      alcoholHighScore: d('alcoholHighScore', 100),
temperatureLowC: d('temperatureLowC', 35),
        temperatureCautionC: d('temperatureCautionC', 37.5),
        temperatureHighC: d('temperatureHighC', 38.5),
        temperatureCautionScore: d('temperatureCautionScore', 40),
        temperatureHighScore: d('temperatureHighScore', 100),
      filterWindow: (json['filterWindow'] as num?)?.toInt() ?? 8,
      temperatureAmbientFloorC: d('temperatureAmbientFloorC', 12),
      temperatureAmbientCeilingC: d('temperatureAmbientCeilingC', 45),
    );
  }
}

/// The full output of one AWTRA evaluation, including the per-channel
/// breakdown. The breakdown is what makes the advanced screen able to show why
/// a score was reached rather than just the score itself.
class AwtraResult {
  const AwtraResult({
    required this.evaluatedAt,
    required this.score,
    required this.band,
    required this.alcoholPpmRaw,
    required this.alcoholPpmFiltered,
    required this.temperatureCRaw,
    required this.temperatureCFiltered,
    required this.alcoholContribution,
    required this.temperatureContribution,
    required this.sensorFault,
    required this.filterPrimed,
    required this.alcoholChannelAlert,
    required this.temperatureChannelAlert,
  });

  final DateTime evaluatedAt;

  /// Weighted risk score, 0\u2013100.
  final double score;
  final RiskBand band;

  final double alcoholPpmRaw;
  final double alcoholPpmFiltered;
  final double temperatureCRaw;
  final double temperatureCFiltered;

  /// Points contributed by each channel after weighting.
  final double alcoholContribution;
  final double temperatureContribution;

  /// True when a reading fell outside the plausible range and was therefore
  /// treated as a sensor fault rather than as an extreme value.
  final bool sensorFault;

  /// False while the moving-average window is still filling.
  final bool filterPrimed;

  /// AWTRA combines two channels into one score, which means a single channel can
  /// be individually exceeded while the combined band stays low. These flags
  /// exist so the UI can still surface "temperature threshold exceeded" rather
  /// than letting the scalar band hide it.
  final bool alcoholChannelAlert;
  final bool temperatureChannelAlert;
}

/// Adaptive Weighted Threshold Risk Algorithm.
///
/// This is rule-based threshold logic that runs on the Arduino Nano in the real
/// device. It is explicitly **not** a trained machine-learning model, and this
/// Dart implementation mirrors the firmware so the monitoring application can
/// preview classification.
///
/// Pipeline: read MQ-3 and MLX90614 \u2192 moving-average filter \u2192 per-channel
/// threshold evaluation \u2192 weighted score \u2192 status band.
class Awtra {
  Awtra(this.config)
      : _alcoholFilter = MovingAverage(config.filterWindow),
        _temperatureFilter = MovingAverage(config.filterWindow);

  AwtraConfig config;
  final MovingAverage _alcoholFilter;
  final MovingAverage _temperatureFilter;

  double get alcoholFilter => _alcoholFilter.average;
  double get temperatureFilter => _temperatureFilter.average;
  bool get filterPrimed =>
      _alcoholFilter.isPrimed && _temperatureFilter.isPrimed;

  /// Number of buffered samples, exposed for the filter-priming indicator.
  int get bufferedSamples =>
      _alcoholFilter.sampleCount < _temperatureFilter.sampleCount
          ? _alcoholFilter.sampleCount
          : _temperatureFilter.sampleCount;

  /// Feeds one raw sample pair through the filters and returns the evaluation.
  ///
  /// Passing the already-filtered values instead would double-filter, so the
  /// caller must always pass raw sensor values here.
  AwtraResult evaluate({
    required DateTime at,
    required double alcoholPpm,
    required double temperatureC,
  }) {
    _alcoholFilter.add(alcoholPpm);
    _temperatureFilter.add(temperatureC);

    final filteredAlcohol = _alcoholFilter.average;
    final filteredTemp = _temperatureFilter.average;

    final tempFault = filteredTemp < config.temperatureAmbientFloorC ||
        filteredTemp > config.temperatureAmbientCeilingC ||
        !filteredTemp.isFinite;

    final alcoholScore = tempFault
        ? 0.0
        : _alcoholPoints(filteredAlcohol);
    final temperatureScore =
        tempFault ? 0.0 : _temperaturePoints(filteredTemp);

    final alcoholWeight = config.alcoholWeight.clamp(0.0, 1.0);
    final temperatureWeight = (1.0 - alcoholWeight).clamp(0.0, 1.0);

    final total = (alcoholScore * alcoholWeight +
            temperatureScore * temperatureWeight)
        .clamp(0.0, 100.0);

    final rounded = total.roundToDouble();

    // Per-channel alerts are computed independently of the weighted total so
    // that a single exceeded channel is never hidden by the combined band.
    final alcoholAlert = !tempFault &&
        filteredAlcohol.isFinite &&
        filteredAlcohol > config.alcoholCautionPpm;
    final temperatureAlert = !tempFault &&
        filteredTemp.isFinite &&
        (filteredTemp > config.temperatureCautionC ||
            filteredTemp < config.temperatureLowC);

    return AwtraResult(
      evaluatedAt: at,
      score: rounded,
      band: RiskBand.fromScore(rounded),
      alcoholPpmRaw: alcoholPpm,
      alcoholPpmFiltered: filteredAlcohol,
      temperatureCRaw: temperatureC,
      temperatureCFiltered: filteredTemp,
      alcoholContribution: alcoholScore * alcoholWeight,
      temperatureContribution: temperatureScore * temperatureWeight,
      sensorFault: tempFault,
      filterPrimed: filterPrimed,
      alcoholChannelAlert: alcoholAlert,
      temperatureChannelAlert: temperatureAlert,
    );
  }

  /// Linear ramp between the caution and high thresholds, so the score
  /// degrades gradually rather than stepping.
  double _alcoholPoints(double ppm) {
    if (!ppm.isFinite || ppm <= 0) return 0;
    final caution = config.alcoholCautionPpm;
    final high = math.max(config.alcoholHighPpm, caution + 1e-6);
    if (ppm <= caution) return 0;
    if (ppm >= high) return config.alcoholHighScore;
    final t = (ppm - caution) / (high - caution);
    return config.alcoholCautionScore +
        t * (config.alcoholHighScore - config.alcoholCautionScore);
  }

  /// Two-sided: both elevated and abnormally low temperatures contribute.
  ///
  /// The physiologically normal span `[temperatureLowC, temperatureCautionC]`
  /// scores **zero**. Only outside that span does the channel contribute, so a
  /// healthy 36.7 C reading never accumulates risk points.
  double _temperaturePoints(double celsius) {
    if (!celsius.isFinite) return 0;

    final low = config.temperatureLowC;
    final caution = config.temperatureCautionC;
    final high = math.max(config.temperatureHighC, caution + 1e-6);

    if (celsius >= high) return config.temperatureHighScore;

    if (celsius > caution) {
      final t = (celsius - caution) / (high - caution);
      return config.temperatureCautionScore +
          t * (config.temperatureHighScore - config.temperatureCautionScore);
    }

    if (celsius >= low) return 0; // Normal range: no contribution.

    // Below the low bound, ramp from 0 at the plausibility floor up to the
    // caution score as it ascends to `low`.
    final floor = config.temperatureAmbientFloorC;
    if (celsius <= floor) return 0;
    final t = (celsius - floor) / (low - floor);
    return config.temperatureCautionScore * t.clamp(0.0, 1.0);
  }

  void reset() {
    _alcoholFilter.clear();
    _temperatureFilter.clear();
  }
}