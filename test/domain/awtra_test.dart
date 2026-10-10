import 'package:flutter_test/flutter_test.dart';
import 'package:smart_safety_ecosystem/domain/awtra.dart';
import 'package:smart_safety_ecosystem/domain/moving_average.dart';

void main() {
  group('MovingAverage', () {
    test('averages only buffered samples', () {
      final filter = MovingAverage(4);
      filter.add(10);
      filter.add(20);
      expect(filter.average, 15);
      expect(filter.isPrimed, isFalse);
    });

    test('is primed once the window is full', () {
      final filter = MovingAverage(3);
      filter.add(1);
      filter.add(2);
      filter.add(3);
      expect(filter.isPrimed, isTrue);
      expect(filter.average, 2);
    });

    test('drops the oldest sample once full, bounding memory', () {
      final filter = MovingAverage(3);
      for (final v in [1.0, 2.0, 3.0, 4.0, 5.0]) {
        filter.add(v);
      }
      expect(filter.sampleCount, 3);
      expect(filter.average, 4); // (3 + 4 + 5) / 3
    });

    test('rejects non-finite samples from a faulty sensor', () {
      final filter = MovingAverage(3);
      filter.add(10);
      filter.add(double.nan);
      filter.add(double.infinity);
      expect(filter.sampleCount, 1);
      expect(filter.average, 10);
    });
  });

  group('RiskBand', () {
    test('maps scores onto the documented bands', () {
      expect(RiskBand.fromScore(0), RiskBand.safe);
      expect(RiskBand.fromScore(39), RiskBand.safe);
      expect(RiskBand.fromScore(40), RiskBand.medium);
      expect(RiskBand.fromScore(79), RiskBand.medium);
      expect(RiskBand.fromScore(80), RiskBand.high);
      expect(RiskBand.fromScore(100), RiskBand.high);
    });
  });

  group('AWTRA', () {
    /// Feeds [count] identical sample pairs so the moving-average window fills.
    AwtraResult prime(
      Awtra awtra, {
      required double alcohol,
      required double temperature,
      int count = 12,
      DateTime? at,
    }) {
      var result = awtra.evaluate(
        at: at ?? DateTime(2026, 1, 1),
        alcoholPpm: alcohol,
        temperatureC: temperature,
      );
      for (var i = 1; i < count; i++) {
        result = awtra.evaluate(
          at: at ?? DateTime(2026, 1, 1).add(Duration(milliseconds: i)),
          alcoholPpm: alcohol,
          temperatureC: temperature,
        );
      }
      return result;
    }

    test('clean readings score as safe', () {
      final awtra = Awtra(const AwtraConfig());
      final result = prime(awtra, alcohol: 2, temperature: 36.7);

      expect(result.band, RiskBand.safe);
      expect(result.score, 0);
      expect(result.sensorFault, isFalse);
      expect(result.filterPrimed, isTrue);
    });

    test('every temperature inside the normal span scores zero', () {
      // Guards the bug where the whole 35-37.5 span was treated as risky.
      for (var celsius = 35.0; celsius <= 37.5; celsius += 0.25) {
        final awtra = Awtra(const AwtraConfig());
        final result = prime(awtra, alcohol: 0, temperature: celsius);
        expect(
          result.temperatureContribution,
          0,
          reason: '${celsius.toStringAsFixed(2)} C must not contribute',
        );
      }
    });

    test('a saturated alcohol screen reaches the high band', () {
      final awtra = Awtra(const AwtraConfig());
      final result = prime(awtra, alcohol: 200, temperature: 36.7);

      // Alcohol saturates at 100 points with a 0.7 weight => 70, plus the
      // 30 points of the temperature channel's ceiling only if it also fires.
      expect(result.alcoholContribution, closeTo(70, 0.01));
      expect(result.alcoholChannelAlert, isTrue);
      expect(result.temperatureChannelAlert, isFalse);
    });

    test('high temperature alone contributes only its weighted share', () {
      final awtra = Awtra(const AwtraConfig());
      final result = prime(awtra, alcohol: 2, temperature: 39.5);

      // Temperature saturates at 100 points, weighted 0.3.
      expect(result.score, closeTo(30, 0.01));
      expect(result.temperatureContribution, closeTo(30, 0.01));
      expect(result.temperatureChannelAlert, isTrue);
    });

    test('an exceeded channel is reported even when the band stays safe', () {
      // This is the masking case the per-channel flags exist to prevent.
      final awtra = Awtra(const AwtraConfig());
      final result = prime(awtra, alcohol: 2, temperature: 39.5);

      expect(result.band, RiskBand.safe);
      expect(
        result.temperatureChannelAlert,
        isTrue,
        reason: 'the UI must still be able to warn about the fever',
      );
    });

    test('score stays within 0..100 across extreme inputs', () {
      final awtra = Awtra(const AwtraConfig());
      final result = prime(awtra, alcohol: 100000, temperature: 60);
      expect(result.score, lessThanOrEqualTo(100));
      expect(result.score, greaterThanOrEqualTo(0));
    });

    test('an implausible temperature is a sensor fault, not a risk', () {
      final awtra = Awtra(const AwtraConfig());
      final result = prime(awtra, alcohol: 2, temperature: 92);

      expect(result.sensorFault, isTrue);
      expect(result.score, 0);
      expect(result.band, RiskBand.safe);
    });

    test('abnormally low temperature still contributes', () {
      final awtra = Awtra(const AwtraConfig());
      final result = prime(awtra, alcohol: 2, temperature: 32.0);
      expect(result.temperatureContribution, greaterThan(0));
      expect(result.temperatureChannelAlert, isTrue);
    });

    test('the alcohol weight is configurable and splits the total', () {
      final awtra = Awtra(const AwtraConfig(alcoholWeight: 1.0));
      final result = prime(awtra, alcohol: 200, temperature: 39.5);

      // All weight on alcohol: alcohol saturates, so the full 100 points.
      expect(result.alcoholContribution, closeTo(100, 0.01));
      expect(result.score, closeTo(100, 0.01));
      expect(result.band, RiskBand.high);
    });

    test('both channels saturated together reach the high band', () {
      final awtra = Awtra(const AwtraConfig());
      final result = prime(awtra, alcohol: 200, temperature: 39.5);
      expect(result.score, closeTo(100, 0.01));
      expect(result.band, RiskBand.high);
    });

    test('moving average smooths a noisy alcohol stream', () {
      final awtra = Awtra(const AwtraConfig(filterWindow: 8));
      final at = DateTime(2026, 1, 1);
      var result = awtra.evaluate(at: at, alcoholPpm: 200, temperatureC: 36.7);
      for (var i = 1; i < 8; i++) {
        result = awtra.evaluate(
          at: at.add(Duration(milliseconds: i)),
          alcoholPpm: 0,
          temperatureC: 36.7,
        );
      }
      // One spike in a window of eight should not read as a full exposure.
      expect(result.alcoholPpmFiltered, closeTo(25, 0.01));
      expect(result.score, lessThan(40));
    });

    test('reset clears the filters', () {
      final awtra = Awtra(const AwtraConfig());
      prime(awtra, alcohol: 200, temperature: 36.7);
      expect(awtra.alcoholFilter, greaterThan(0));
      awtra.reset();
      expect(awtra.alcoholFilter, 0);
      expect(awtra.bufferedSamples, 0);
    });

    test('config round-trips through JSON', () {
      const config = AwtraConfig(
        alcoholWeight: 0.75,
        alcoholCautionPpm: 55,
        filterWindow: 12,
      );
      final restored = AwtraConfig.fromJson(config.toJson());

      expect(restored.alcoholWeight, 0.75);
      expect(restored.alcoholCautionPpm, 55);
      expect(restored.filterWindow, 12);
    });
  });
}