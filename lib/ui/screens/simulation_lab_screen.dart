import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../domain/models/severity.dart';
import '../../domain/simulation/scenario.dart';
import '../../domain/simulation/simulation_engine.dart';
import '../../state/app_controller.dart';
import '../components/surface_card.dart';
import '../components/telemetry_chart.dart';
import '../shell/app_shell.dart';

/// The Simulation Lab.
///
/// Demo Mode lives here. Scenarios are deterministic and repeatable, run
/// entirely offline, and feed the production [AccidentDetector] rather than a
/// parallel mock, so what is demonstrated is the real algorithm.
class SimulationLabScreen extends StatelessWidget {
  const SimulationLabScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        controller,
        controller.settings,
      ]),
      builder: (context, _) {
        return PageBody(
          children: [
            if (!controller.isDemo)
              const NoticeBanner(
                title: 'Simulation Lab is only available in Demo Mode',
                message:
                    'Switch to Demo Mode to run scripted scenarios. In Real '
                    'Hardware Mode the app must use live device data and will '
                    'not substitute simulated readings.',
                severity: Severity.info,
                icon: Icons.info_outline,
              ),
            if (!controller.isDemo) const SizedBox(height: Insets.lg),
            _ScenarioPicker(controller: controller),
            const SizedBox(height: Insets.lg),
            _PlaybackCard(controller: controller),
            const SizedBox(height: Insets.lg),
            _LiveCharts(controller: controller),
            const SizedBox(height: Insets.lg),
            const NoticeBanner(
              title: 'Simulated data',
              message:
                  'Everything on this screen is generated locally. No device, '
                  'radio, gateway or network is used, and no real emergency '
                  'call or external notification can be made.',
              severity: Severity.info,
              icon: Icons.science_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _ScenarioPicker extends StatelessWidget {
  const _ScenarioPicker({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final selected = controller.engine.scenario;
    final layout = context.layoutSize;
    final twoColumn = layout == LayoutSize.large;

    final cards = [
      for (final scenario in Scenarios.all)
        _ScenarioCard(
          scenario: scenario,
          selected: scenario.id == selected.id,
          onTap: () => controller.selectScenario(scenario.id),
        ),
    ];

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Scenario', style: theme.textTheme.titleLarge),
          const SizedBox(height: Insets.xs),
          Text(
            'Each scenario is scripted and repeatable. The same run always '
            'produces the same samples, event and outcome.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          if (twoColumn)
            Wrap(
              spacing: Insets.md,
              runSpacing: Insets.md,
              children: [
                for (var i = 0; i < cards.length; i++)
                  SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.45 - Insets.md,
                    child: cards[i],
                  ),
              ],
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
          if (selected.notes.isNotEmpty) ...[
            const SizedBox(height: Insets.lg),
            Container(
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: Radii.control,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final note in selected.notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(note, style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.selected,
    required this.onTap,
  });

  final Scenario scenario;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.card,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.standard,
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: selected ? colors.demoAccentMuted : colors.surfaceAlt,
            borderRadius: Radii.card,
            border: Border.all(
              color: selected ? colors.demoAccent : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scenario.name,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      size: 15,
                      color: colors.demoAccent,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(scenario.description, style: theme.textTheme.bodySmall),
              const SizedBox(height: Insets.md),
              Wrap(
                spacing: Insets.sm,
                runSpacing: 4,
                children: [
                  _Tag(text: '${scenario.duration.inSeconds}s'),
                  if (!scenario.gpsAvailable) const _Tag(text: 'No GPS'),
                  if (!scenario.gatewayAvailable)
                    const _Tag(text: 'No gateway', severity: Severity.caution),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.severity});

  final String text;
  final Severity? severity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = severity == null
        ? colors.textSecondary
        : colors.forSeverity(severity!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: severity == null
            ? colors.surface
            : colors.mutedForSeverity(severity!),
        borderRadius: Radii.pill,
        border: Border.all(color: colors.border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final engine = controller.engine;
    final scenario = engine.scenario;
    final playing = engine.state == PlaybackState.playing;
    final finished = engine.state == PlaybackState.finished;

    return SurfaceCard(
      accent: colors.demoAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scenario.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(switch (engine.state) {
                      PlaybackState.idle => 'Ready to play',
                      PlaybackState.playing => 'Playing',
                      PlaybackState.paused => 'Paused',
                      PlaybackState.finished => 'Finished',
                    }, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                '${formatElapsed(engine.elapsed)} / '
                '${formatElapsed(scenario.duration)}',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          ClipRRect(
            borderRadius: Radii.pill,
            child: LinearProgressIndicator(
              value: controller.simulationProgress,
            ),
          ),
          const SizedBox(height: Insets.xl),
          // Primary transport controls.
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.isDemo ? engine.toggle : null,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    playing
                        ? 'Pause'
                        : finished
                        ? 'Replay'
                        : 'Play',
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              OutlinedButton(
                onPressed: controller.isDemo
                    ? controller.resetSimulation
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(52, kMinTouchTarget),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.stop_rounded),
              ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Playback speed',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                '${engine.speed.toStringAsFixed(2)}\u00D7',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: engine.speed,
            min: 0.25,
            max: 4,
            divisions: 15,
            onChanged: controller.isDemo ? controller.setPlaybackSpeed : null,
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            children: [
              for (final speed in const [0.5, 1.0, 2.0, 4.0])
                ChoiceChip(
                  label: Text('${speed.toStringAsFixed(1)}\u00D7'),
                  selected: (engine.speed - speed).abs() < 0.01,
                  onSelected: controller.isDemo
                      ? (_) => controller.setPlaybackSpeed(speed)
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveCharts extends StatelessWidget {
  const _LiveCharts({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final twoColumn = context.layoutSize == LayoutSize.large;
    final stage = controller.detector.stage;

    final accel = TelemetryChart(
      buffer: controller.accelSeries.buffer,
      color: colors.accent,
      unit: 'g',
      label: 'Acceleration magnitude',
      min: 0,
      threshold: controller.settings.thresholds.impactG,
      height: 150,
    );

    final tilt = TelemetryChart(
      buffer: controller.tiltSeries.buffer,
      color: colors.accentSecondary,
      unit: '\u00B0',
      label: 'Tilt',
      min: 0,
      threshold: controller.settings.thresholds.rolloverDegrees,
      height: 150,
    );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Live telemetry', style: theme.textTheme.titleLarge),
          const SizedBox(height: Insets.xs),
          Text(
            'Stage: ${stage.label} \u2014 ${stage.description}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
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

/// Formats a duration as `m:ss`.
String formatElapsed(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
