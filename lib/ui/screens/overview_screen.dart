import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../data/app_settings.dart';
import '../../domain/accident_detector.dart';
import '../../domain/models/geo.dart';
import '../../domain/models/incident.dart';
import '../../domain/models/lora.dart';
import '../../domain/models/severity.dart';
import '../../state/app_controller.dart';
import '../components/surface_card.dart';
import '../components/mode_indicator.dart';
import '../shell/app_navigation.dart';
import '../shell/navigation_scope.dart';
import '../shell/app_shell.dart';

/// The default landing screen.
///
/// Deliberately simple: mode, the two device statuses, connectivity, the most
/// recent incidents, the latest valid position and one primary action. Anything
/// raw or calibration-shaped is behind the Advanced toggle.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final layout = context.layoutSize;
    final theme = Theme.of(context);
    final detector = controller.detector;

    // The two-column dashboard needs real room: below ~1360px the side column
    // squeezes the primary action and the metric tiles into unreadable stubs.
    // Everything below that width stacks, with the device cards still sitting
    // side by side inside `_deviceGrid`.
    final twoColumn = layout == LayoutSize.large;
    final columns = twoColumn ? 2 : 1;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        controller,
        controller.incidentStore.listenable,
        controller.settings,
      ]),
      builder: (context, _) {
        final mostSevere = controller.mostSevereOpen;

        return PageBody(
          children: [
            _buildHeader(context, controller),
            const SizedBox(height: Insets.lg),
            // A critical warning is never hidden behind an advanced toggle, so
            // these banners sit above the fold unconditionally.
            if (mostSevere != null) ...[
              NoticeBanner(
                title: 'Active alert \u2014 ${mostSevere.summary}',
                message: mostSevere.wasDelivered
                    ? 'The gateway confirmed receipt. Review the record and '
                          'follow up with the nearby facility.'
                    : 'Delivery not confirmed. The packet may not have reached '
                          'a gateway.',
                severity: Severity.critical,
                icon: Icons.campaign_outlined,
                actionLabel: 'Open incident',
                onAction: () => _showIncident(context, mostSevere),
              ),
              const SizedBox(height: Insets.md),
            ],
            if (detector.stage.isActionable) ...[
              NoticeBanner(
                title: 'Cancellation window open',
                message:
                    'A possible impact was detected. If it was harmless, '
                    'cancel it before the packet is built.',
                severity: Severity.caution,
                icon: Icons.timer_outlined,
                actionLabel: 'Cancel false alarm',
                onAction: () {
                  final cancelled = controller.detector.cancelEvent();
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          cancelled
                              ? 'False alarm cancelled. No packet was sent.'
                              : 'The cancellation window has closed.',
                        ),
                      ),
                    );
                },
              ),
              const SizedBox(height: Insets.md),
            ],
            if (controller.isHardware) ...[
              const NoticeBanner(
                title: 'Real Hardware Mode',
                message:
                    'Readings come from connected devices. Values that no '
                    'device has reported stay empty \u2014 nothing is '
                    'substituted.',
                severity: Severity.info,
                icon: Icons.sensors,
              ),
              const SizedBox(height: Insets.md),
            ],
            if (columns == 1) ...[
              _primaryAction(context, controller, theme),
              const SizedBox(height: Insets.lg),
              _deviceGrid(context, controller, layout),
              const SizedBox(height: Insets.lg),
              _connectivityCard(context, controller),
              const SizedBox(height: Insets.lg),
              _recentIncidents(context, controller),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _deviceGrid(context, controller, layout),
                        const SizedBox(height: Insets.lg),
                        _recentIncidents(context, controller),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.lg),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _primaryAction(context, controller, theme),
                        const SizedBox(height: Insets.lg),
                        _connectivityCard(context, controller),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppController controller) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.isDemo ? 'Simulated monitoring' : 'Live monitoring',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 2),
              Text(
                controller.isDemo
                    ? 'Scripted data from the Simulation Lab. No device or '
                          'network is in use.'
                    : 'Live data from connected devices.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        ModeIndicator(mode: controller.mode),
      ],
    );
  }

  Widget _primaryAction(
    BuildContext context,
    AppController controller,
    ThemeData theme,
  ) {
    final running = controller.isRunning;
    return SurfaceCard(
      accent: controller.isDemo ? context.colors.demoAccent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            controller.isDemo ? 'Run a demonstration' : 'Start live monitoring',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            controller.isDemo
                ? 'Play a scripted scenario end to end: detection, '
                      'confirmation, cancellation window, GPS and LoRa '
                      'transmission.'
                : 'Begin reading from the connected vehicle node and wearable.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: controller.toggleRunning,
            icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
            // The button already constrains its label, so a plain ellipsising
            // Text is enough to stay safe at large text scales.
            label: Text(
              running ? 'Stop monitoring' : 'Start monitoring',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: Insets.sm),
          TextButton(
            onPressed: () => _openSimulationLab(context),
            child: Text(
              running ? 'Open Simulation Lab' : 'Go to Simulation Lab',
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceGrid(
    BuildContext context,
    AppController controller,
    LayoutSize layout,
  ) {
    final perRow = layout.isCompact ? 1 : 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = perRow == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - Insets.md) / 2;
        return Wrap(
          spacing: Insets.md,
          runSpacing: Insets.md,
          children: [
            SizedBox(
              width: width,
              child: _VehicleStatusCard(controller: controller),
            ),
            SizedBox(
              width: width,
              child: _WearableStatusCard(controller: controller),
            ),
          ],
        );
      },
    );
  }

  Widget _connectivityCard(BuildContext context, AppController controller) {
    final theme = Theme.of(context);
    final detector = controller.detector;
    final fix = controller.currentFix;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Latest valid position', style: theme.textTheme.titleMedium),
          const SizedBox(height: Insets.md),
          if (fix == null)
            Row(
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 18,
                  color: context.colors.textTertiary,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    'No position has been received yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: context.colors.accent,
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        fix.display,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                MetricRow(
                  tiles: [
                    MetricTile(
                      label: 'Satellites',
                      value: '${fix.satellites}',
                      icon: Icons.satellite_alt_outlined,
                    ),
                    MetricTile(
                      label: 'Accuracy',
                      value: fix.accuracyMetres.toStringAsFixed(0),
                      unit: 'm',
                      icon: Icons.radar_outlined,
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: Insets.lg),
          Divider(color: context.colors.border, height: 1),
          const SizedBox(height: Insets.md),
          DetailRow(
            label: 'Detection stage',
            value: detector.stage.label,
            valueColor: detector.stage.isActionable
                ? context.colors.warning
                : null,
          ),
          DetailRow(label: 'Trigger reason', value: detector.reason.label),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showLocationSheet(context, fix),
                  icon: const Icon(Icons.map_outlined, size: 17),
                  label: const Text('Open map panel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recentIncidents(BuildContext context, AppController controller) {
    final theme = Theme.of(context);
    final incidents = controller.incidentStore.all.take(4).toList();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent incidents',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => _goTo(context, AppDestination.incidents),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          if (incidents.isEmpty)
            EmptyState(
              compact: true,
              icon: Icons.inbox_outlined,
              title: 'No incidents recorded',
              message:
                  'Alerts from the vehicle node and screening records from '
                  'the wristband appear here.',
              actionLabel: 'Open Simulation Lab',
              onAction: () => _openSimulationLab(context),
            )
          else
            for (final incident in incidents)
              IncidentRow(
                incident: incident,
                onTap: () => _showIncident(context, incident),
              ),
        ],
      ),
    );
  }

  void _showIncident(BuildContext context, Incident incident) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(incident.summary),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailRow(
              label: 'Occurred',
              value: _formatTime(incident.occurredAt),
            ),
            DetailRow(label: 'Device', value: incident.deviceId),
            DetailRow(label: 'Origin', value: incident.origin.label),
            if (incident.location != null)
              DetailRow(label: 'Position', value: incident.location!.display),
            if (incident.deliveryOutcome != null)
              DetailRow(
                label: 'Delivery',
                value: incident.wasDelivered
                    ? 'Confirmed by gateway'
                    : 'Not confirmed',
                valueColor: incident.wasDelivered
                    ? context.colors.success
                    : context.colors.warning,
              ),
            if (incident.attempts > 0)
              DetailRow(
                label: 'Attempts / ACKs',
                value: '${incident.attempts} / ${incident.acknowledgements}',
              ),
            if (incident.notes.isNotEmpty) ...[
              const SizedBox(height: Insets.sm),
              for (final note in incident.notes)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '\u2022 $note',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLocationSheet(BuildContext context, GeoFix? fix) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Position', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Insets.md),
              if (fix == null)
                Text(
                  'No position has been received yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                PositionMapPanel(fix: fix),
            ],
          ),
        ),
      ),
    );
  }

  void _openSimulationLab(BuildContext context) =>
      NavigationScope.go(context, AppDestination.simulation);

  void _goTo(BuildContext context, AppDestination destination) =>
      NavigationScope.go(context, destination);
}

/// Vehicle node status.
class _VehicleStatusCard extends StatelessWidget {
  const _VehicleStatusCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detector = controller.detector;
    final stage = detector.stage;
    final severity = switch (stage) {
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
          CardHeader(
            title: 'Vehicle node',
            icon: Icons.directions_car_filled_outlined,
            trailing: StatusBadge(
              label: controller.isDemo ? stage.label : 'No device',
              severity: controller.isDemo ? severity : Severity.info,
              icon: controller.isDemo
                  ? Icons.science_outlined
                  : Icons.usb_off_outlined,
              dense: true,
            ),
          ),
          const SizedBox(height: Insets.md),
          if (controller.isDemo) ...[
            Text(stage.description, style: theme.textTheme.bodySmall),
            const SizedBox(height: Insets.md),
            MetricRow(
              tiles: [
                MetricTile(
                  label: 'Peak acceleration',
                  value: detector
                      .currentResult()
                      .peakAccelerationG
                      .toStringAsFixed(1),
                  unit: 'g',
                  icon: Icons.speed_outlined,
                ),
                MetricTile(
                  label: 'Live magnitude',
                  value:
                      controller.accelSeries.latest?.toStringAsFixed(2) ??
                      '\u2014',
                  unit: 'g',
                  icon: Icons.motion_photos_on_outlined,
                ),
              ],
            ),
          ] else
            Text(
              'No vehicle node is connected, so no readings are shown. Connect a '
              'device in Real Hardware Mode to begin.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// Wearable status.
class _WearableStatusCard extends StatelessWidget {
  const _WearableStatusCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = controller.wearableResult;

    return SurfaceCard(
      accent: result == null
          ? context.colors.border
          : context.colors.forSeverity(result.band.severity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Wearable',
            icon: Icons.watch_outlined,
            trailing: result != null
                ? StatusBadge(
                    label: result.band.label,
                    severity: result.band.severity,
                    icon: result.band.severity == Severity.safe
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    dense: true,
                  )
                : const StatusBadge(
                    label: 'Idle',
                    severity: Severity.info,
                    icon: Icons.pause_circle_outline,
                    dense: true,
                  ),
          ),
          const SizedBox(height: Insets.md),
          if (result == null)
            Text(
              'The wristband classifies readings locally. Start monitoring to '
              'see its current classification.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            MetricRow(
              tiles: [
                MetricTile(
                  label: 'Risk score',
                  value: result.score.toStringAsFixed(0),
                  unit: '/ 100',
                  severity: result.band.severity,
                  hint:
                      'AWTRA weighted score. Bands: 0\u201339 safe, '
                      '40\u201379 medium, 80+ high.',
                ),
                MetricTile(
                  label: 'Alcohol',
                  value: result.alcoholPpmFiltered.toStringAsFixed(1),
                  unit: 'ppm',
                  severity: result.alcoholChannelAlert
                      ? Severity.caution
                      : null,
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            MetricRow(
              tiles: [
                MetricTile(
                  label: 'Temperature',
                  value: result.temperatureCFiltered.toStringAsFixed(1),
                  unit: '\u00B0C',
                  severity: result.temperatureChannelAlert
                      ? Severity.caution
                      : null,
                ),
                MetricTile(
                  label: 'Band',
                  value: result.band.range,
                  hint: 'Documented score band.',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact incident row reused by the overview and history screens.
class IncidentRow extends StatelessWidget {
  const IncidentRow({super.key, required this.incident, this.onTap});

  final Incident incident;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    final icon = switch (incident.category) {
      IncidentCategory.accident => Icons.car_crash_outlined,
      IncidentCategory.screening => Icons.monitor_heart_outlined,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.control,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.mutedForSeverity(incident.severity),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 17,
                color: colors.forSeverity(incident.severity),
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incident.summary,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${_formatTime(incident.occurredAt)} \u00B7 '
                    '${incident.deviceId}'
                    '${incident.isSimulated ? ' \u00B7 Simulated' : ''}',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: StatusBadge(
                  label: incident.status.label,
                  severity: incident.status.tone,
                  dense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact, dependency-free position panel.
///
/// A full map tile stack would add a heavy dependency and a network call for
/// something the monitoring view only needs at a glance, so this shows the
/// coordinates with a schematic marker instead.
class PositionMapPanel extends StatelessWidget {
  const PositionMapPanel({super.key, required this.fix});

  final GeoFix fix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: Radii.card,
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          // Schematic grid, purely decorative and clearly not a real map.
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter(colors.chartGrid)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, size: 30, color: colors.accent),
                const SizedBox(height: Insets.xs),
                Text(fix.display, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Schematic position \u2014 not a survey map',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const spacing = 28.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.color != color;
}

/// Formats a timestamp as a short local time.
String _formatTime(DateTime when) {
  final local = when.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

/// Formats a timestamp as a relative age, e.g. "4 min ago".
String formatRelative(DateTime when, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final delta = reference.difference(when);
  if (delta.inSeconds < 5) return 'just now';
  if (delta.inSeconds < 60) return '${delta.inSeconds} s ago';
  if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
  if (delta.inHours < 24) return '${delta.inHours} h ago';
  return '${delta.inDays} d ago';
}

/// Convenience accessor used by several screens.
extension OperatingModeLabel on OperatingMode {
  String get shortLabel => isDemo ? 'Demo' : 'Live';
}

/// Re-exported so screens can render a LoRa outcome label consistently.
String describeOutcome(TransmissionOutcome outcome) => switch (outcome) {
  TransmissionOutcome.acknowledged => 'Confirmed by gateway',
  TransmissionOutcome.sentUnacknowledged => 'Sent, not confirmed',
  TransmissionOutcome.noGatewayInRange => 'No gateway in range',
  TransmissionOutcome.radioFailure => 'Radio failure',
  TransmissionOutcome.fallbackGsm => 'Sent via GSM fallback',
};
