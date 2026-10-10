import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../domain/models/lora.dart';
import '../../domain/models/severity.dart';
import '../../state/app_controller.dart';
import '../components/surface_card.dart';
import '../shell/app_shell.dart';

/// Lists the hardware this build knows about and is honest about what is
/// actually connected.
class DeviceManagerScreen extends StatelessWidget {
  const DeviceManagerScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        controller,
        controller.settings,
      ]),
      builder: (context, _) => PageBody(
        children: [
          if (controller.isDemo) ...[
            const NoticeBanner(
              title: 'Demo Mode',
              message:
                  'The devices below are part of the simulated setup. They '
                  'are not physically attached and no radio traffic exists.',
              severity: Severity.info,
              icon: Icons.science_outlined,
            ),
            const SizedBox(height: Insets.lg),
          ],
          _DeviceList(controller: controller),
          const SizedBox(height: Insets.lg),
          _GatewayCard(controller: controller),
          const SizedBox(height: Insets.lg),
          _TopologyNote(),
        ],
      ),
    );
  }
}

/// A device as the application understands it.
class _DeviceInfo {
  const _DeviceInfo({
    required this.id,
    required this.name,
    required this.kind,
    required this.role,
    required this.components,
  });

  final String id;
  final String name;
  final String kind;
  final String role;
  final List<String> components;
}

const List<_DeviceInfo> _vehicles = <_DeviceInfo>[
  _DeviceInfo(
    id: 'VN-01',
    name: 'Vehicle node VN-01',
    kind: 'Vehicle',
    role: 'Accident detection and LoRa alert',
    components: <String>['Accelerometer', 'Gyroscope', 'GPS', 'LoRa'],
  ),
];

const List<_DeviceInfo> _wearables = <_DeviceInfo>[
  _DeviceInfo(
    id: 'WB-01',
    name: 'Wristband WB-01',
    kind: 'Wearable',
    role: 'Preliminary alcohol and temperature screening',
    components: <String>[
      'Arduino Nano',
      'MQ-3',
      'MLX90614',
      'SSD1306 OLED',
      'Buzzer',
      'LEDs',
    ],
  ),
];

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = <_DeviceInfo>[..._vehicles, ..._wearables];

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Devices', style: theme.textTheme.titleLarge),
          const SizedBox(height: Insets.xs),
          Text(
            'Status reflects real connections only. In Real Hardware Mode with '
            'nothing attached, every device reports unavailable.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          for (var i = 0; i < devices.length; i++) ...[
            if (i > 0) const SizedBox(height: Insets.lg),
            _DeviceRow(device: devices[i], controller: controller),
          ],
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.controller});

  final _DeviceInfo device;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    // Demo Mode: the simulation is running. Hardware mode: nothing is attached.
    final (severity, statusLabel, statusIcon) = controller.isDemo
        ? (Severity.info, 'Simulated', Icons.science_outlined)
        : (Severity.info, 'Not connected', Icons.usb_off_outlined);

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: Radii.card,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  device.kind == 'Vehicle'
                      ? Icons.directions_car_outlined
                      : Icons.watch_outlined,
                  size: 19,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: theme.textTheme.titleSmall),
                    Text(
                      '${device.id} \u00B7 ${device.kind}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: statusLabel,
                severity: severity,
                icon: statusIcon,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(device.role, style: theme.textTheme.bodySmall),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: 4,
            children: [
              for (final component in device.components)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: Radii.pill,
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(component, style: theme.textTheme.labelSmall),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GatewayCard extends StatelessWidget {
  const _GatewayCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const params = LoraRadioParams();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gateway and radio',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              StatusBadge(
                label: controller.isDemo ? 'Simulated' : 'Not connected',
                severity: Severity.info,
                icon: controller.isDemo
                    ? Icons.science_outlined
                    : Icons.router_outlined,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            'LoRa is only the radio link between the vehicle node and a '
            'gateway. The gateway forwards packets to a backend, which performs '
            'facility lookup and notification \u2014 LoRa alone never contacts a '
            'hospital.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          const Divider(height: 1),
          const SizedBox(height: Insets.md),
          MetricRow(
            tiles: [
              MetricTile(
                label: 'Frequency',
                value: params.frequencyMhz.toStringAsFixed(0),
                unit: 'MHz',
                icon: Icons.waves_outlined,
              ),
              MetricTile(
                label: 'Spreading factor',
                value: '${params.spreadingFactor}',
                icon: Icons.tune_outlined,
              ),
              MetricTile(
                label: 'Bandwidth',
                value: '${params.bandwidthKhz}',
                unit: 'kHz',
                icon: Icons.speed_outlined,
              ),
            ],
          ),
          if (!controller.isDemo) ...[
            const SizedBox(height: Insets.lg),
            const NoticeBanner(
              title: 'No gateway in range',
              message:
                  'Transmission attempts will fail and be reported as failed. '
                  'The app will not present an undelivered packet as a success.',
              severity: Severity.caution,
              icon: Icons.router_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

class _TopologyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Signal path', style: theme.textTheme.titleMedium),
          const SizedBox(height: Insets.md),
          const _TopologyRow(
            icon: Icons.sensors,
            label: 'Vehicle node',
            detail: 'IMU, GPS, microcontroller, LoRa',
          ),
          const _TopologyRow(
            icon: Icons.arrow_downward,
            label: 'LoRa radio link',
            detail: 'Compact packet, long range, low power',
          ),
          const _TopologyRow(
            icon: Icons.router_outlined,
            label: 'LoRa gateway',
            detail: 'Receives and forwards over the internet',
          ),
          const _TopologyRow(
            icon: Icons.dns_outlined,
            label: 'Backend',
            detail: 'Facility lookup and notification',
          ),
          const SizedBox(height: Insets.md),
          Text(
            'LoRa needs gateway coverage. Where cellular service is available, '
            'a GSM fallback is an optional path. A backend outage is handled by '
            'queueing and retrying.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TopologyRow extends StatelessWidget {
  const _TopologyRow({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: colors.textSecondary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
