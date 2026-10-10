import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../domain/models/severity.dart';
import '../components/surface_card.dart';
import '../shell/app_shell.dart';

/// About this application: what it is, what it is built from, and what it does
/// not claim.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PageBody(
      maxWidth: 860,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(Insets.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SafetyConstellation()),
              const SizedBox(height: Insets.xxl),
              Text(
                'Smart Safety Ecosystem',
                style: theme.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'LoRa-Based Accident Alert and Portable Wearable Risk '
                'Screening System',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.xxl),
              const _AboutSection(
                title: 'What this is',
                body:
                    'Two complementary safety functions behind one monitoring '
                    'console. The vehicle subsystem detects a possible collision '
                    'or rollover, gives the driver a short window to cancel a '
                    'false alarm, captures a GPS position and sends a compact '
                    'alert through a LoRa gateway to a backend. The wearable '
                    'subsystem screens for alcohol exposure and monitors '
                    'temperature, classifying the result locally.',
              ),
              const _AboutSection(
                title: 'What it does not do',
                body:
                    'The wristband cannot identify narcotic or psychotropic '
                    'substances, does not diagnose fever or intoxication, and '
                    'cannot prove the cause of an accident. LoRa alone never '
                    'contacts a hospital: the gateway and backend perform the '
                    'routing. No measured accuracy or response-time figures have '
                    'been established.',
              ),
              const _AboutSection(
                title: 'How detection works',
                body:
                    'Accelerometer and gyroscope data is read continuously. A '
                    'candidate event is checked against calibrated thresholds '
                    'over a confirmation window. If confirmed, a warning '
                    'activates and a manual cancellation window opens. If it is '
                    'not cancelled, the device acquires a GPS fix, builds a '
                    'compact packet and transmits it over LoRa. Without a fix '
                    'the packet is still sent, flagged.',
              ),
              const _AboutSection(
                title: 'AWTRA',
                body:
                    'The Adaptive Weighted Threshold Risk Algorithm filters the '
                    'MQ-3 and MLX90614 readings with a moving average, evaluates '
                    'each against thresholds, combines them into a weighted '
                    'score and maps that to a band: 0\u201339 safe, 40\u201379 '
                    'medium risk, 80 and above high risk. It is rule-based '
                    'threshold logic running on a microcontroller, not a trained '
                    'machine-learning model, and these are prototype values '
                    'needing calibration and validation.',
              ),
              const _AboutSection(
                title: 'Modes',
                body:
                    'Demo Mode uses scripted, repeatable data entirely offline '
                    'and can never send a real notification. Real Hardware Mode '
                    'reads live data and reports anything unavailable as '
                    'unavailable, never substituting simulated readings. '
                    'Transmission attempts and confirmed acknowledgements are '
                    'shown as separate counts.',
              ),
              const SizedBox(height: Insets.md),
              const NoticeBanner(
                title: 'Before real-world use',
                message:
                    'Emergency use requires appropriate safety validation. Any '
                    'substance screening requires a validated method and '
                    'confirmatory testing where the law requires it. Screening '
                    'should only be carried out with consent and authorisation.',
                severity: Severity.caution,
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: Insets.sm),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A restrained, layered vector illustration of the two subsystems and the
/// path between them.
///
/// This is deliberately a painted composition rather than a 3D scene: the
/// product brief asks for depth without a heavy renderer, and a full 3D
/// dashboard would cost performance and legibility for no added meaning. The
/// sense of depth comes from stacked translucent planes, a soft ambient
/// shadow and a slow parallax response to pointer movement.
class SafetyConstellation extends StatefulWidget {
  const SafetyConstellation({super.key, this.size = 190});

  final double size;

  @override
  State<SafetyConstellation> createState() => _SafetyConstellationState();
}

class _SafetyConstellationState extends State<SafetyConstellation> {
  Offset _tilt = Offset.zero;

  /// Parallax depth in logical pixels at maximum offset.
  static const double _maxShift = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      label:
          'Illustration: a vehicle node and a wearable connected through a '
          'gateway to a backend',
      image: true,
      child: MouseRegion(
        onHover: (event) {
          if (reduceMotion) return;
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final centre = box.size.center(Offset.zero);
          final local = event.localPosition - centre;
          final normalised = Offset(
            local.dx / (box.size.width / 2),
            local.dy / (box.size.height / 2),
          );
          setState(() {
            _tilt = Offset(
              normalised.dx.clamp(-1.0, 1.0) * _maxShift,
              normalised.dy.clamp(-1.0, 1.0) * _maxShift,
            );
          });
        },
        onExit: (_) => setState(() => _tilt = Offset.zero),
        child: AnimatedContainer(
          duration: Motion.slow,
          curve: Motion.standard,
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ConstellationPainter(
              accent: colors.accent,
              accentSecondary: colors.accentSecondary,
              surface: colors.surfaceElevated,
              border: colors.border,
              highlight: colors.highlight,
              offset: reduceMotion ? Offset.zero : _tilt,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({
    required this.accent,
    required this.accentSecondary,
    required this.surface,
    required this.border,
    required this.highlight,
    required this.offset,
  });

  final Color accent;
  final Color accentSecondary;
  final Color surface;
  final Color border;
  final Color highlight;
  final Offset offset;

  /// Maximum parallax travel, matching the interactive widget.
  static const double maxShift = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);

    // Layered back planes, offset progressively for a parallax depth effect.
    for (var layer = 2; layer >= 0; layer--) {
      final depth = (2 - layer) * maxShift * 0.4;
      final inset = layer * 16.0;
      final rect = Rect.fromCenter(
        center: centre + offset * (0.3 + layer * 0.25) + Offset(0, depth),
        width: size.width - inset * 2,
        height: size.height - inset * 2,
      );
      final rrect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(Radii.lg),
      );

      canvas.drawShadow(
        Path()..addRRect(rrect),
        Colors.black.withValues(alpha: 0.35),
        18,
        false,
      );

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = surface.withValues(alpha: 0.35 + layer * 0.2)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = border.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      // A single metallic lip along the top edge of each plane.
      final lip = Path()
        ..moveTo(rect.left + Radii.lg, rect.top)
        ..lineTo(rect.right - Radii.lg, rect.top);
      canvas.drawPath(
        lip,
        Paint()
          ..color = highlight.withValues(alpha: 0.35)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }

    final nodeY = size.height * 0.28;
    const nodeRadius = 15.0;

    // The two subsystems.
    _node(
      canvas,
      Offset(size.width * 0.24 + offset.dx, nodeY + offset.dy),
      nodeRadius,
      Icons.directions_car_filled_outlined,
      accent,
    );
    _node(
      canvas,
      Offset(size.width * 0.76 + offset.dx, nodeY + offset.dy),
      nodeRadius,
      Icons.watch_outlined,
      accentSecondary,
    );

    // The gateway in the middle, slightly forward.
    final gateway = Offset(centre.dx, size.height * 0.58 + offset.dy * 1.4);
    _node(canvas, gateway, nodeRadius * 1.15, Icons.router_outlined, accent);

    // Connection paths.
    _link(
      canvas,
      Offset(size.width * 0.24 + offset.dx, nodeY + offset.dy + nodeRadius),
      gateway - const Offset(0, nodeRadius * 1.15),
      accent,
    );
    _link(
      canvas,
      Offset(size.width * 0.76 + offset.dx, nodeY + offset.dy + nodeRadius),
      gateway - const Offset(0, nodeRadius * 1.15),
      accentSecondary,
    );

    // The backend beneath.
    final backend = Offset(centre.dx, size.height * 0.85 + offset.dy * 1.7);
    _link(
      canvas,
      gateway + const Offset(0, nodeRadius * 1.15),
      backend - const Offset(0, 12),
      border,
    );
    _node(canvas, backend, 12, Icons.dns_outlined, highlight);
  }

  void _node(
    Canvas canvas,
    Offset centre,
    double radius,
    IconData icon,
    Color color,
  ) {
    canvas.drawCircle(
      centre,
      radius + 6,
      Paint()..color = color.withValues(alpha: 0.12),
    );
    canvas.drawCircle(centre, radius, Paint()..color = surface);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Icons are not available inside a Canvas, so the glyph is composed from
    // primitives instead of fighting TextPainter.
    final inner = radius * 0.52;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre, width: inner * 2, height: inner * 1.5),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: centre + Offset(0, inner * 0.1),
        width: inner * 0.9,
        height: inner * 0.35,
      ),
      Paint()..color = surface,
    );
  }

  void _link(Canvas canvas, Offset from, Offset to, Color color) {
    final control = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 - 14);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_ConstellationPainter oldDelegate) =>
      oldDelegate.offset != offset ||
      oldDelegate.accent != accent ||
      oldDelegate.surface != surface;
}

/// A gentle animated accent used sparingly on the welcome screen.
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.35 + t * 0.5),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3 * (1 - t)),
                  blurRadius: 10 * t,
                  spreadRadius: 2 * t,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Exposed for the welcome screen.
double radiansFor(double degrees) => degrees * math.pi / 180.0;
