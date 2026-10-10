import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../data/app_settings.dart';
import '../../domain/awtra.dart';
import '../../domain/models/severity.dart';
import '../../state/app_controller.dart';
import '../components/mode_indicator.dart';
import '../components/surface_card.dart';
import '../shell/app_shell.dart';

/// Settings: appearance, operating mode, advanced controls and notifications.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        controller,
        controller.settings,
        controller.incidentStore.listenable,
      ]),
      builder: (context, _) {
        final settings = controller.settings;

        return PageBody(
          maxWidth: 900,
          children: [
            _AppearanceSection(settings: settings),
            const SizedBox(height: Insets.lg),
            _ModeSection(controller: controller),
            const SizedBox(height: Insets.lg),
            _AdvancedSection(controller: controller, settings: settings),
            const SizedBox(height: Insets.lg),
            _NotificationSection(controller: controller, settings: settings),
            const SizedBox(height: Insets.lg),
            _DataSection(controller: controller, settings: settings),
            const SizedBox(height: Insets.lg),
            _ScopeNote(),
          ],
        );
      },
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Appearance',
            subtitle: 'Applies immediately, no restart needed.',
            icon: Icons.palette_outlined,
          ),
          SegmentedButton<AppThemePreference>(
            segments: [
              for (final preference in AppThemePreference.values)
                ButtonSegment<AppThemePreference>(
                  value: preference,
                  label: Text(preference.label),
                  icon: Icon(switch (preference) {
                    AppThemePreference.light => Icons.light_mode_outlined,
                    AppThemePreference.dark => Icons.dark_mode_outlined,
                    AppThemePreference.system => Icons.brightness_auto_outlined,
                  }),
                ),
            ],
            selected: {settings.themePreference},
            onSelectionChanged: (selection) =>
                settings.setThemePreference(selection.first),
          ),
          const SizedBox(height: Insets.md),
          Text(
            settings.themePreference == AppThemePreference.system
                ? 'Following your system appearance.'
                : 'Always using the ${settings.themePreference.label.toLowerCase()} theme.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ModeSection extends StatelessWidget {
  const _ModeSection({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Operating mode',
            subtitle: 'Determines whether the app may use live devices.',
            icon: Icons.tune_outlined,
          ),
          ModeSelectorCard(
            mode: OperatingMode.demo,
            selected: controller.mode.isDemo,
            onSelect: (_) => _switch(context, OperatingMode.demo),
          ),
          const SizedBox(height: Insets.md),
          ModeSelectorCard(
            mode: OperatingMode.hardware,
            selected: controller.mode.isHardware,
            onSelect: (_) => _switch(context, OperatingMode.hardware),
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Changing mode always asks for confirmation and stops any running '
            'monitoring.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _switch(BuildContext context, OperatingMode target) async {
    final shell = context;
    // Reuse the shell's confirmation flow so there is exactly one place where a
    // mode change is authorised.
    final messenger = ScaffoldMessenger.of(shell);
    if (controller.mode == target) return;

    final accepted = await confirmAction(
      context,
      title: target.isHardware
          ? 'Switch to Real Hardware Mode?'
          : 'Switch to Demo Mode?',
      message: target.isHardware
          ? 'The app will read live data from connected devices. Anything not '
                'connected stays empty \u2014 no simulated values are substituted.'
          : 'The app will use scripted data with no device, radio or network.',
      confirmLabel: 'Switch mode',
    );
    if (!accepted) return;

    await controller.settings.setMode(target);
    controller.setRunning(false);
    if (target.isDemo) {
      controller.resetSimulation();
    } else {
      controller.rearmDetector();
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Mode: ${target.label}')));
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({required this.controller, required this.settings});

  final AppController controller;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Advanced controls',
            subtitle:
                'Unlocks threshold editors, raw streams and packet inspection.',
            icon: Icons.tune,
          ),
          SettingSwitch(
            title: 'Enable Advanced mode',
            subtitle:
                'Turn this on only when you intend to change detection or '
                'screening calibration. Ordinary use does not need it.',
            icon: Icons.developer_mode_outlined,
            value: settings.advancedMode,
            onChanged: (value) async {
              if (!value) {
                await settings.setAdvancedMode(false);
                return;
              }
              final accepted = await confirmAction(
                context,
                title: 'Enable Advanced mode?',
                message:
                    'Detection thresholds and AWTRA weights become editable. '
                    'Changing these alters when the system reports an accident '
                    'or a screening result, so they should only be adjusted with '
                    'a calibration procedure.',
                confirmLabel: 'Enable',
              );
              if (accepted) await settings.setAdvancedMode(true);
            },
          ),
          if (settings.advancedMode) ...[
            const SizedBox(height: Insets.sm),
            Container(
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: context.colors.warningMuted,
                borderRadius: Radii.control,
                border: Border.all(
                  color: context.colors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 17,
                    color: context.colors.warning,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      'Calibration values are preliminary. They must be '
                      'validated per vehicle and per wearer before field use.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            _ThresholdSummary(controller: controller),
            const SizedBox(height: Insets.lg),
            _AwtraSummary(controller: controller),
          ],
        ],
      ),
    );
  }
}

class _ThresholdSummary extends StatelessWidget {
  const _ThresholdSummary({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.settings.thresholds;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Accident detection', style: theme.textTheme.titleSmall),
        const SizedBox(height: Insets.md),
        MetricRow(
          tiles: [
            MetricTile(
              label: 'Impact',
              value: t.impactG.toStringAsFixed(2),
              unit: 'g',
            ),
            MetricTile(
              label: 'Rollover',
              value: t.rolloverDegrees.toStringAsFixed(0),
              unit: '\u00B0',
            ),
            MetricTile(
              label: 'Confirm',
              value: (t.confirmWindowMs / 1000).toStringAsFixed(2),
              unit: 's',
            ),
            MetricTile(
              label: 'Cancel',
              value: (t.cancelWindowMs / 1000).toStringAsFixed(1),
              unit: 's',
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        Text(
          'Edit these on the Accident Monitor screen.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AwtraSummary extends StatelessWidget {
  const _AwtraSummary({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller.settings.awtra;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Wearable screening (AWTRA)', style: theme.textTheme.titleSmall),
        const SizedBox(height: Insets.md),
        MetricRow(
          tiles: [
            MetricTile(
              label: 'Alcohol weight',
              value: (c.alcoholWeight * 100).toStringAsFixed(0),
              unit: '%',
            ),
            MetricTile(
              label: 'Alcohol caution',
              value: c.alcoholCautionPpm.toStringAsFixed(0),
              unit: 'ppm',
            ),
            MetricTile(
              label: 'Temp caution',
              value: c.temperatureCautionC.toStringAsFixed(1),
              unit: '\u00B0C',
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        Text(
          'Bands: 0\u201339 safe, 40\u201379 medium risk, 80+ high risk. '
          'Edit on the Wearable Monitor screen.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({
    required this.controller,
    required this.settings,
  });

  final AppController controller;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Notifications',
            subtitle: 'In-app banners only by default.',
            icon: Icons.notifications_none_outlined,
          ),
          SettingSwitch(
            title: 'In-app incident banners',
            subtitle: 'Show a banner when a new alert is recorded.',
            icon: Icons.notifications_outlined,
            value: settings.notificationsEnabled,
            onChanged: settings.setNotificationsEnabled,
          ),
          const Divider(height: Insets.xxl),
          SettingSwitch(
            title: 'Authorise external notifications',
            subtitle:
                'Off by default. Enabling this allows the app to send real '
                'dispatches to external recipients.',
            icon: Icons.outgoing_mail,
            value: settings.externalNotificationsArmed,
            onChanged: (value) async {
              if (!value) {
                await settings.setExternalNotificationsArmed(false);
                return;
              }
              final accepted = await confirmAction(
                context,
                title: 'Authorise external notifications?',
                message:
                    'The app will be permitted to send real notifications to '
                    'configured external recipients. Confirm with the people '
                    'who would receive them, and only enable this in a context '
                    'where that is appropriate and lawful.',
                confirmLabel: 'Authorise',
              );
              if (accepted) await settings.setExternalNotificationsArmed(true);
            },
          ),
          if (settings.externalNotificationsArmed) ...[
            const SizedBox(height: Insets.sm),
            const NoticeBanner(
              title: 'External notifications are armed',
              message:
                  'Records may be dispatched outside the application. This is '
                  'independent of operating mode and persists across restarts.',
              severity: Severity.caution,
              icon: Icons.outgoing_mail,
            ),
          ],
          const SizedBox(height: Insets.sm),
          Text(
            'Demo Mode can never send an external notification, regardless of '
            'this setting.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection({required this.controller, required this.settings});

  final AppController controller;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = controller.incidentStore;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Stored data',
            icon: Icons.storage_outlined,
          ),
          DetailRow(label: 'Incident records', value: '${store.count}'),
          DetailRow(label: 'Active records', value: '${store.open.length}'),
          DetailRow(
            label: 'Retention limit',
            value: '${store.capacity} records',
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Records are stored in a JSON document inside the application data '
            'directory and are written on every change.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          OutlinedButton.icon(
            onPressed: () => _clearIncidents(context, store),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.critical,
            ),
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text('Clear incident history'),
          ),
          const SizedBox(height: Insets.lg),
          Divider(color: context.colors.border, height: 1),
          const SizedBox(height: Insets.lg),
          Text('Reset', style: theme.textTheme.titleSmall),
          const SizedBox(height: Insets.xs),
          Text(
            'Restores every setting to its default, including the Light theme.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.md),
          OutlinedButton.icon(
            onPressed: () => _resetAll(context),
            icon: const Icon(Icons.restart_alt, size: 17),
            label: const Text('Restore defaults'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearIncidents(BuildContext context, dynamic store) async {
    final accepted = await confirmAction(
      context,
      title: 'Clear incident history?',
      message: 'All stored records will be permanently deleted.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!accepted) return;
    await store.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('History cleared.')));
    }
  }

  Future<void> _resetAll(BuildContext context) async {
    final accepted = await confirmAction(
      context,
      title: 'Restore all defaults?',
      message:
          'Theme returns to Light, mode returns to Demo, and every '
          'calibration value is reset. Incident records are not affected.',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (!accepted) return;
    await settings.resetToDefaults();
    await controller.setAwtraConfig(const AwtraConfig());
    controller.resetSimulation();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Defaults restored.')));
    }
  }
}

/// A permanent statement of what this application does and does not claim.
class _ScopeNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Scope and limitations',
            subtitle: 'What this system does not do.',
            icon: Icons.fact_check_outlined,
          ),
          _ScopePoint(
            text:
                'No measured accuracy or response-time figures are reported. '
                'All performance fields are unvalidated.',
          ),
          _ScopePoint(
            text:
                'Wearable screening is preliminary. It does not diagnose '
                'fever or intoxication, and a positive reading is never proof.',
          ),
          _ScopePoint(
            text:
                'The MQ-3 responds to gases other than alcohol vapour. '
                'Readings depend on calibration and environment.',
          ),
          _ScopePoint(
            text:
                'Screening records and accident alerts are separate '
                'categories. A screening result never implies cause of an '
                'accident.',
          ),
          _ScopePoint(
            text:
                'Emergency use requires appropriate safety validation. '
                'Substance screening requires validated methods and '
                'confirmatory testing where the law requires it.',
          ),
          _ScopePoint(
            text:
                'Gateway coverage, sensor calibration, interference, power, '
                'false positives, privacy and regulatory approval are known '
                'limitations.',
          ),
        ],
      ),
    );
  }
}

class _ScopePoint extends StatelessWidget {
  const _ScopePoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 15,
            color: context.colors.textTertiary,
          ),
          const SizedBox(width: Insets.md),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
