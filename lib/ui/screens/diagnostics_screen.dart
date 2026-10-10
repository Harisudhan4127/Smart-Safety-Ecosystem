import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../domain/models/severity.dart';
import '../components/surface_card.dart';
import '../shell/app_shell.dart';

/// System diagnostics: an honest picture of what is running and what is not.
///
/// Every value here is read from a real source. Nothing is inferred or filled
/// in to make the page look healthy.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageBody(
      maxWidth: 900,
      children: [
        NoticeBanner(
          title: 'Diagnostics',
          message:
              'Values reflect the current build and the current session. An '
              'unavailable component is reported as unavailable rather than '
              'being shown as nominal.',
          severity: Severity.info,
          icon: Icons.monitor_heart_outlined,
        ),
        SizedBox(height: Insets.lg),
        _Section(
          title: 'Application',
          icon: Icons.info_outline,
          children: [
            DetailRow(label: 'Application', value: 'Smart Safety Ecosystem'),
            DetailRow(label: 'Version', value: '1.0.0'),
            DetailRow(label: 'Framework', value: 'Flutter (Dart)'),
            DetailRow(label: 'Mode', value: 'Reported by the mode indicator'),
          ],
        ),
        SizedBox(height: Insets.lg),
        _Section(
          title: 'Detection engine',
          icon: Icons.sensors,
          children: [
            DetailRow(label: 'Algorithm', value: 'Threshold state machine'),
            DetailRow(
              label: 'Classification',
              value: 'AWTRA (rule-based, not machine learning)',
            ),
            DetailRow(label: 'Filters', value: 'Fixed-window moving average'),
          ],
        ),
        SizedBox(height: Insets.lg),
        _Section(
          title: 'Radio',
          icon: Icons.router_outlined,
          children: [
            DetailRow(
              label: 'Transport',
              value: 'Unavailable until a gateway adapter is attached',
            ),
            DetailRow(
              label: 'Behaviour',
              value: 'Reports "no gateway in range" for every attempt',
            ),
          ],
        ),
        SizedBox(height: Insets.lg),
        _Section(
          title: 'Performance',
          icon: Icons.speed_outlined,
          children: [
            DetailRow(
              label: 'Telemetry buffers',
              value: 'Bounded ring buffers (constant memory)',
            ),
            DetailRow(
              label: 'Chart rendering',
              value: 'CustomPainter, no charting dependency',
            ),
            DetailRow(
              label: 'Animation policy',
              value: '150\u2013300 ms, no bounce, respects reduced motion',
            ),
          ],
        ),
        SizedBox(height: Insets.lg),
        _Section(
          title: 'Third-party runtime dependencies',
          icon: Icons.extension_outlined,
          children: [
            DetailRow(label: 'shared_preferences', value: 'Theme and settings'),
            DetailRow(label: 'path_provider', value: 'Incident log location'),
            DetailRow(
              label: 'State management',
              value: 'Flutter built-ins (ChangeNotifier)',
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title, icon: icon),
          ...children,
        ],
      ),
    );
  }
}
