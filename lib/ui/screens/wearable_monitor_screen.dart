import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../domain/awtra.dart';
import '../../domain/models/severity.dart';
import '../../state/app_controller.dart';
import '../components/surface_card.dart';
import '../components/telemetry_chart.dart';
import '../shell/app_shell.dart';

/// Wearable screening view.
///
/// Shows the current AWTRA classification and its two input channels. The
/// per-channel warnings are surfaced separately from the combined score, because
/// a single exceeded channel can otherwise be hidden by a low weighted total.
class WearableMonitorScreen extends StatelessWidget {
  const WearableMonitorScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        controller,
        controller.settings,
      ]),
      builder: (context, _) {
        final result = controller.wearableResult;
        final advanced = controller.settings.advancedMode;

        return PageBody(
          children: [
            if (result == null)
              SurfaceCard(
                child: EmptyState(
                  icon: Icons.watch_outlined,
                  title: 'Wearable is idle',
                  message:
                      'The wristband runs its measurement cycle locally and '
                      'needs no cloud connection. Start monitoring to classify '
                      'the current readings.',
                  actionLabel: 'Start monitoring',
                  onAction: controller.toggleRunning,
                ),
              )
            else ...[
              _ClassificationCard(controller: controller, result: result),
              const SizedBox(height: Insets.lg),
              _ChannelCard(controller: controller, result: result),
              const SizedBox(height: Insets.lg),
              _BandLegend(),
              const SizedBox(height: Insets.lg),
              const NoticeBanner(
                title: 'Preliminary screening only',
                message:
                    'This is an indication to follow up, not a diagnosis. The '
                    'MQ-3 can respond to gases other than alcohol vapour, and '
                    'the MLX90614 reading depends on distance and ambient '
                    'conditions. A positive screening result is never proof, and '
                    'it does not imply that anyone caused an accident.',
                severity: Severity.info,
                icon: Icons.info_outline,
              ),
              if (advanced) ...[
                const SizedBox(height: Insets.lg),
                _WeightsPanel(controller: controller),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard({required this.controller, required this.result});

  final AppController controller;
  final AwtraResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final severity = result.band.severity;

    return SurfaceCard(
      accent: colors.forSeverity(severity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current classification',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              StatusBadge(
                label: result.band.label,
                severity: severity,
                icon: severity == Severity.safe
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          _ScoreDial(score: result.score, band: result.band),
          const SizedBox(height: Insets.xl),
          Text(
            result.band.action,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'Score band ${result.band.range} of 100',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (result.sensorFault) ...[
            const SizedBox(height: Insets.lg),
            const NoticeBanner(
              title: 'Temperature sensor fault',
              message:
                  'A reading fell outside the plausible range and has been '
                  'ignored rather than treated as an extreme value. The alcohol '
                  'channel is not contributing until this clears.',
              severity: Severity.caution,
              icon: Icons.thermostat_outlined,
            ),
          ],
          if (!result.filterPrimed) ...[
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Icon(
                  Icons.hourglass_top_outlined,
                  size: 15,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'Filling the moving-average filter. Readings stabilise once '
                    'the window is full.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A ring gauge for the risk score.
class _ScoreDial extends StatelessWidget {
  const _ScoreDial({required this.score, required this.band});

  final double score;
  final RiskBand band;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = colors.forSeverity(band.severity);

    return Center(
      child: SizedBox(
        width: 168,
        height: 168,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: score),
          duration: Motion.slow,
          curve: Motion.decelerate,
          builder: (context, value, _) => CustomPaint(
            painter: _DialPainter(
              value: value,
              color: color,
              track: colors.surfaceAlt,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.displayMedium
                        ?.copyWith(color: color),
                  ),
                  Text('of 100', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const stroke = 10.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final sweep = (value / 100).clamp(0.0, 1.0) * 6.283185307;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.570796327,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.controller, required this.result});

  final AppController controller;
  final AwtraResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final config = controller.settings.awtra;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Input channels', style: theme.textTheme.titleLarge),
          const SizedBox(height: Insets.xs),
          Text(
            'Raw and filtered readings from the two sensors.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          TelemetryChart(
            buffer: controller.alcoholSeries.buffer,
            color: colors.accent,
            unit: 'ppm',
            label: 'MQ-3 alcohol',
            min: 0,
            threshold: config.alcoholCautionPpm,
          ),
          const SizedBox(height: Insets.xl),
          TelemetryChart(
            buffer: controller.temperatureSeries.buffer,
            color: colors.accentSecondary,
            unit: '\u00B0C',
            label: 'MLX90614 temperature',
            threshold: config.temperatureCautionC,
          ),
          const SizedBox(height: Insets.lg),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: Insets.md),
          // Each channel reports its own state, independent of the combined
          // band, so one exceeded threshold is never masked by the score.
          _ChannelRow(
            name: 'MQ-3 alcohol sensor',
            raw: result.alcoholPpmRaw,
            filtered: result.alcoholPpmFiltered,
            unit: 'ppm',
            threshold: config.alcoholCautionPpm,
            alert: result.alcoholChannelAlert,
          ),
          const SizedBox(height: Insets.md),
          _ChannelRow(
            name: 'MLX90614 temperature',
            raw: result.temperatureCRaw,
            filtered: result.temperatureCFiltered,
            unit: '\u00B0C',
            threshold: config.temperatureCautionC,
            alert: result.temperatureChannelAlert,
            lowThreshold: config.temperatureLowC,
          ),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.name,
    required this.raw,
    required this.filtered,
    required this.unit,
    required this.threshold,
    required this.alert,
    this.lowThreshold,
  });

  final String name;
  final double raw;
  final double filtered;
  final String unit;
  final double threshold;
  final bool alert;
  final double? lowThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
            StatusBadge(
              label: alert ? 'Above threshold' : 'Within range',
              severity: alert ? Severity.caution : Severity.safe,
              icon: alert ? Icons.trending_up : Icons.check,
              dense: true,
            ),
          ],
        ),
        const SizedBox(height: 6),
        MetricRow(
          tiles: [
            MetricTile(label: 'Raw', value: raw.toStringAsFixed(2), unit: unit),
            MetricTile(
              label: 'Filtered',
              value: filtered.toStringAsFixed(2),
              unit: unit,
              severity: alert ? Severity.caution : null,
            ),
            MetricTile(
              label: lowThreshold == null ? 'Threshold' : 'Range',
              value: lowThreshold == null
                  ? threshold.toStringAsFixed(0)
                  : '${lowThreshold!.toStringAsFixed(1)}\u2013${threshold.toStringAsFixed(1)}',
              unit: unit,
            ),
          ],
        ),
        if (alert)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Reading is outside the expected range. Treat as an indication '
              'to follow up, not a confirmed result.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.warning),
            ),
          ),
      ],
    );
  }
}

/// The documented score bands, always shown so the classification is legible.
class _BandLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final layout = context.layoutSize;

    final cards = [
      for (final band in RiskBand.values)
        Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: colors.mutedForSeverity(band.severity),
            borderRadius: Radii.card,
            border: Border.all(
              color: colors.forSeverity(band.severity).withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    band.severity == Severity.safe
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    size: 15,
                    color: colors.forSeverity(band.severity),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(band.label, style: theme.textTheme.titleSmall),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(band.range, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(band.action, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
    ];

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Score bands', style: theme.textTheme.titleLarge),
          const SizedBox(height: Insets.xs),
          Text(
            'AWTRA is rule-based threshold logic running on the '
            'microcontroller. It is not a trained machine-learning model.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          if (layout == LayoutSize.large)
            // IntrinsicHeight gives the band cards a common height; a bare
            // Row with stretch alignment would demand infinite height instead.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: Insets.md),
                    Expanded(child: cards[i]),
                  ],
                ],
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: Insets.md),
                  cards[i],
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// AWTRA weight editor, shown only with Advanced mode enabled.
class _WeightsPanel extends StatelessWidget {
  const _WeightsPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = controller.settings.awtra;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AWTRA weights and thresholds',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'These are prototype calibration values. Changing them alters how '
            'a screening result is classified.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alcohol weight',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                '${(config.alcoholWeight * 100).toStringAsFixed(0)}% / '
                '${((1 - config.alcoholWeight) * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: context.colors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: config.alcoholWeight,
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: (value) => controller.setAwtraConfig(
              config.copyWith(alcoholWeight: value),
            ),
          ),
          const SizedBox(height: Insets.sm),
          MetricRow(
            tiles: [
              MetricTile(
                label: 'Alcohol caution',
                value: config.alcoholCautionPpm.toStringAsFixed(0),
                unit: 'ppm',
              ),
              MetricTile(
                label: 'Alcohol high',
                value: config.alcoholHighPpm.toStringAsFixed(0),
                unit: 'ppm',
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          MetricRow(
            tiles: [
              MetricTile(
                label: 'Temp caution',
                value: config.temperatureCautionC.toStringAsFixed(1),
                unit: '\u00B0C',
              ),
              MetricTile(
                label: 'Temp high',
                value: config.temperatureHighC.toStringAsFixed(1),
                unit: '\u00B0C',
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          OutlinedButton(
            onPressed: () => controller.setAwtraConfig(const AwtraConfig()),
            child: const Text('Restore defaults'),
          ),
        ],
      ),
    );
  }
}
