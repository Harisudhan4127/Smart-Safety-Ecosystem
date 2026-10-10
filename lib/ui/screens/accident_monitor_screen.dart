import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../domain/accident_detector.dart';
import '../../domain/models/geo.dart';
import '../../domain/models/lora.dart';
import '../../domain/models/severity.dart';
import '../../state/app_controller.dart';
import '../components/surface_card.dart';
import '../components/telemetry_chart.dart';
import '../shell/app_shell.dart';
import 'overview_screen.dart';

/// Live vehicle-side detection view.
///
/// The default view shows the detection stage, the filtered telemetry and the
/// transmission record. Calibration thresholds and the raw packet inspector sit
/// behind the Advanced toggle, because editing a production threshold without
/// understanding the consequence is unsafe.
class AccidentMonitorScreen extends StatelessWidget {
  const AccidentMonitorScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        controller,
        controller.settings,
      ]),
      builder: (context, _) {
        final advanced = controller.settings.advancedMode;

        return PageBody(
          children: [
            _StageCard(controller: controller),
            const SizedBox(height: Insets.lg),
            _TelemetryCard(controller: controller),
            const SizedBox(height: Insets.lg),
            _DeliveryCard(controller: controller),
            const SizedBox(height: Insets.lg),
            if (!controller.isDemo)
              const NoticeBanner(
                title: 'No vehicle node connected',
                message:
                    'Real Hardware Mode is active but no device is reporting, so '
                    'no acceleration, tilt or delivery data is available. '
                    'Values are left empty rather than simulated.',
                severity: Severity.info,
                icon: Icons.usb_off_outlined,
              )
            else if (advanced) ...[
              _ThresholdPanel(controller: controller),
              const SizedBox(height: Insets.lg),
              _RawStreamCard(controller: controller),
              const SizedBox(height: Insets.lg),
              const _CalibrationWarning(),
            ] else
              AdvancedDisclosure(
                title: 'Advanced controls',
                subtitle: 'Thresholds, raw stream and packet inspection',
                icon: Icons.tune,
                child: Builder(
                  builder: (context) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enable the Advanced toggle in Settings to edit '
                        'detection thresholds and inspect raw packets.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: Insets.md),
                      FilledButton.tonal(
                        onPressed: () => _enableAdvanced(context),
                        child: const Text('Enable Advanced mode'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _enableAdvanced(BuildContext context) {
    controller.settings.setAdvancedMode(true);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Advanced mode enabled. Threshold controls unlocked.'),
        ),
      );
  }
}

/// The detection pipeline, shown as a horizontal stepper that reflects the
/// documented flow rather than the internal stage enum.
class _StageCard extends StatelessWidget {
  const _StageCard({required this.controller});

  final AppController controller;

  static const List<DetectionStage> _flow = <DetectionStage>[
    DetectionStage.monitoring,
    DetectionStage.confirming,
    DetectionStage.cancelling,
    DetectionStage.acquiringGps,
    DetectionStage.transmitting,
    DetectionStage.dispatched,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detector = controller.detector;
    final currentIndex = _flow.indexOf(detector.stage);
    final failed = detector.stage == DetectionStage.failed;

    final severity = switch (detector.stage) {
      DetectionStage.warning || DetectionStage.cancelling => Severity.critical,
      DetectionStage.candidate ||
      DetectionStage.confirming ||
      DetectionStage.acquiringGps ||
      DetectionStage.transmitting => Severity.caution,
      DetectionStage.failed => Severity.critical,
      _ => Severity.safe,
    };

    return SurfaceCard(
      accent: context.colors.forSeverity(severity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Detection pipeline',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              StatusBadge(
                label: failed ? 'Failed' : detector.stage.label,
                severity: severity,
                icon: failed ? Icons.error_outline : null,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(detector.stage.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Insets.xl),
          _Stepper(stages: _flow, currentIndex: currentIndex, failed: failed),
          if (detector.stage == DetectionStage.cancelling) ...[
            const SizedBox(height: Insets.xl),
            _CancellationCountdown(controller: controller),
          ],
          if (detector.stage.isActionable) ...[
            const SizedBox(height: Insets.lg),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.critical,
                foregroundColor: context.colors.isDark
                    ? const Color(0xFF2A0A0E)
                    : Colors.white,
              ),
              onPressed: () {
                final ok = controller.detector.cancelEvent();
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'False alarm cancelled. No packet was built.'
                            : 'The cancellation window has already closed.',
                      ),
                    ),
                  );
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel false alarm'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.stages,
    required this.currentIndex,
    required this.failed,
  });

  final List<DetectionStage> stages;
  final int currentIndex;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final horizontal = context.layoutSize != LayoutSize.compact;

    // A six-across stepper would shrink its labels to unreadable stubs on a
    // phone, so narrow layouts get a vertical list with the stage
    // description alongside instead.
    if (!horizontal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stages.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: Row(
                children: [
                  Flexible(
                    child: _StepMarker(
                      stage: stages[i],
                      done: currentIndex > i || failed,
                      active: currentIndex == i && !failed,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      stages[i].description,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepMarker(
                  stage: stages[i],
                  done: currentIndex > i || failed,
                  active: currentIndex == i && !failed,
                ),
              ],
            ),
          ),
          if (i < stages.length - 1)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 14,
                height: 2,
                color: currentIndex > i ? colors.accent : colors.border,
              ),
            ),
        ],
      ],
    );
  }
}

/// The dot plus label for one pipeline stage.
///
/// Intentionally has no stretch alignment: it is placed in Rows that may be
/// unbounded on one axis, and a stretched Column there would demand an infinite
/// constraint.
class _StepMarker extends StatelessWidget {
  const _StepMarker({
    required this.stage,
    required this.done,
    required this.active,
  });

  final DetectionStage stage;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    final color = done
        ? colors.success
        : active
        ? colors.warning
        : colors.border;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: Motion.medium,
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active
                ? color.withValues(alpha: 0.16)
                : Colors.transparent,
            border: Border.all(color: color, width: 1.5),
          ),
          child: done
              ? Icon(Icons.check, size: 13, color: colors.success)
              : active
              ? Center(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: Insets.sm),
        Flexible(
          child: Text(
            stage.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: active || done ? colors.textPrimary : colors.textTertiary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CancellationCountdown extends StatefulWidget {
  const _CancellationCountdown({required this.controller});

  final AppController controller;

  @override
  State<_CancellationCountdown> createState() => _CancellationCountdownState();
}

class _CancellationCountdownState extends State<_CancellationCountdown> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detector = widget.controller.detector;
    final progress = detector.cancelProgress;
    final remaining = detector.cancellationRemaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Time left to cancel',
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              remaining == null
                  ? '\u2014'
                  : '${remaining.inSeconds}.${(remaining.inMilliseconds % 1000) ~/ 100}s',
              style: theme.textTheme.titleSmall?.copyWith(
                color: context.colors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        ClipRRect(
          borderRadius: Radii.pill,
          child: LinearProgressIndicator(value: progress),
        ),
      ],
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final thresholds = controller.settings.thresholds;
    final twoColumn = context.layoutSize == LayoutSize.large;

    final accel = TelemetryChart(
      buffer: controller.accelSeries.buffer,
      color: colors.accent,
      unit: 'g',
      label: 'Acceleration magnitude',
      min: 0,
      threshold: thresholds.impactG,
    );

    final tilt = TelemetryChart(
      buffer: controller.tiltSeries.buffer,
      color: colors.accentSecondary,
      unit: '\u00B0',
      label: 'Tilt from upright',
      min: 0,
      threshold: thresholds.rolloverDegrees,
    );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Motion telemetry',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Tooltip(
                message:
                    'Filtered motion data. The dashed line marks the '
                    'calibrated detection threshold.',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'The dashed line is the threshold above which an event is a candidate.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.xl),
          if (twoColumn)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: accel),
                const SizedBox(width: Insets.xl),
                Expanded(child: tilt),
              ],
            )
          else ...[
            accel,
            const SizedBox(height: Insets.xl),
            tilt,
          ],
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final result = controller.detector.currentResult();
    final packet = result.packet;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Transmission', style: theme.textTheme.titleLarge),
              ),
              if (packet != null)
                StatusBadge(
                  label: result.wasDelivered
                      ? 'Confirmed'
                      : result.isUnresolvedDelivery
                      ? 'Unconfirmed'
                      : 'Not delivered',
                  severity: result.wasDelivered
                      ? Severity.safe
                      : Severity.critical,
                  icon: result.wasDelivered
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          if (packet == null)
            const EmptyState(
              compact: true,
              icon: Icons.podcasts_outlined,
              title: 'No packet sent yet',
              message:
                  'A packet is built only after an event is confirmed and the '
                  'cancellation window closes.',
            )
          else ...[
            DetailRow(
              label: 'Packet',
              value: '#${packet.sequence} \u00B7 ${packet.type.wireName}',
            ),
            DetailRow(label: 'Device', value: packet.deviceId),
            DetailRow(
              label: 'Delivery',
              value: describeOutcome(
                result.outcome ?? TransmissionOutcome.radioFailure,
              ),
              valueColor: result.wasDelivered ? colors.success : colors.warning,
            ),
            DetailRow(label: 'Attempts', value: '${result.attempts}'),
            DetailRow(
              label: 'Acknowledgements',
              value: '${result.acknowledgements}',
              valueColor: result.acknowledgements == 0
                  ? colors.warning
                  : colors.success,
            ),
            DetailRow(
              label: 'Position',
              value: packet.gpsValid
                  ? (packet.location?.display ?? '\u2014')
                  : 'Unavailable \u2014 packet flagged',
              valueColor: packet.gpsValid ? null : colors.warning,
            ),
            if (controller.settings.advancedMode) ...[
              const SizedBox(height: Insets.md),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: Insets.md),
              for (final entry in packet.inspectedFields.entries)
                DetailRow(
                  label: entry.key,
                  value: entry.value,
                  monospace: entry.key == 'Checksum',
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Threshold editors, available only with Advanced mode on.
class _ThresholdPanel extends StatelessWidget {
  const _ThresholdPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = controller.settings.thresholds;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Detection thresholds', style: theme.textTheme.titleLarge),
          const SizedBox(height: Insets.xs),
          Text(
            'These values change when the system decides an impact occurred.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          _SliderRow(
            label: 'Impact threshold',
            value: current.impactG,
            min: 1.5,
            max: 8,
            suffix: 'g',
            hint:
                'Acceleration magnitude above which a collision is suspected.',
            onChanged: (value) =>
                controller.setThresholds(current.copyWith(impactG: value)),
          ),
          _SliderRow(
            label: 'Rollover threshold',
            value: current.rolloverDegrees,
            min: 20,
            max: 100,
            suffix: '\u00B0',
            hint: 'Tilt from upright above which a rollover is suspected.',
            onChanged: (value) => controller.setThresholds(
              current.copyWith(rolloverDegrees: value),
            ),
          ),
          _SliderRow(
            label: 'Confirmation window',
            value: current.confirmWindowMs.toDouble(),
            min: 300,
            max: 5000,
            divisions: 47,
            suffix: 'ms',
            hint: 'How long a candidate must persist before it is confirmed.',
            onChanged: (value) => controller.setThresholds(
              current.copyWith(confirmWindowMs: value.round()),
            ),
          ),
          _SliderRow(
            label: 'Cancellation window',
            value: current.cancelWindowMs.toDouble(),
            min: 1000,
            max: 20000,
            divisions: 38,
            suffix: 'ms',
            hint: 'Time the driver has to cancel a false alarm.',
            onChanged: (value) => controller.setThresholds(
              current.copyWith(cancelWindowMs: value.round()),
            ),
          ),
          const SizedBox(height: Insets.md),
          OutlinedButton(
            onPressed: () =>
                controller.setThresholds(const AccidentThresholds()),
            child: const Text('Restore defaults'),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.hint,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String suffix;
  final String hint;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Tooltip(
                  message: hint,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.help_outline,
                        size: 13,
                        color: context.colors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${value.toStringAsFixed(value >= 100 ? 0 : 2)} $suffix',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: context.colors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// The raw sensor stream, an engineering view.
class _RawStreamCard extends StatelessWidget {
  const _RawStreamCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final latest = controller.accelSeries.latest;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Raw stream', style: theme.textTheme.titleLarge),
          const SizedBox(height: Insets.xs),
          Text(
            'The most recent filtered sample as the detector sees it.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          MetricRow(
            tiles: [
              MetricTile(
                label: 'Acceleration',
                value: latest?.toStringAsFixed(4) ?? '\u2014',
                unit: 'g',
                icon: Icons.speed_outlined,
              ),
              MetricTile(
                label: 'Tilt',
                value:
                    controller.tiltSeries.latest?.toStringAsFixed(3) ??
                    '\u2014',
                unit: '\u00B0',
                icon: Icons.rotate_right_outlined,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          MetricRow(
            tiles: [
              MetricTile(
                label: 'Buffered samples',
                value: '${controller.accelSeries.buffer.length}',
                icon: Icons.stacked_line_chart,
              ),
              MetricTile(
                label: 'Buffer capacity',
                value: '${controller.accelSeries.buffer.capacity}',
                icon: Icons.memory_outlined,
                hint: 'The buffer is bounded so memory use stays constant.',
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Raw axes are not plotted by default to keep the chart readable; '
            'they are available through the device adapter in Real Hardware '
            'Mode.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalibrationWarning extends StatelessWidget {
  const _CalibrationWarning();

  @override
  Widget build(BuildContext context) {
    return const NoticeBanner(
      title: 'Preliminary calibration values',
      message:
          'These thresholds are starting values, not universal crash-detection '
          'standards. They must be calibrated for each vehicle before any field '
          'use, and emergency deployment requires appropriate safety validation.',
      severity: Severity.caution,
      icon: Icons.warning_amber_rounded,
    );
  }
}

/// Re-exported for the simulation screen.
typedef AccidentPosition = GeoFix;
