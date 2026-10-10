import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../domain/models/severity.dart';

/// The standard surface container.
///
/// A single card implementation serves every screen and both themes. In the
/// dark theme it gets a 1px metallic top edge and a soft ambient shadow, which
/// is what produces the machined depth without glow, blur or glassmorphism.
///
/// Set [onTap] to make the card interactive; it then shows hover and pressed
/// feedback and a visible focus ring.
class SurfaceCard extends StatefulWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.xl),
    this.onTap,
    this.accent,
    this.elevated = false,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// When set, tints the top edge to associate the card with a status.
  final Color? accent;

  /// True for menus, sheets and popovers that sit above other cards.
  final bool elevated;

  final EdgeInsetsGeometry? margin;

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = colors.isDark;
    final interactive = widget.onTap != null;

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: MouseRegion(
        cursor: interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: interactive
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: interactive ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: interactive
              ? () => setState(() => _pressed = false)
              : null,
          onTap: widget.onTap,
          child: AnimatedScale(
            // A very small scale on press: enough to feel responsive, not
            // enough to look like a toy.
            scale: _pressed ? 0.992 : 1.0,
            duration: Motion.fast,
            curve: Motion.standard,
            // Material provides the ink and selection behaviour that list
            // tiles, checkboxes and text fields expect from an ancestor; without
            // it Material asserts that their background is invisible.
            child: Material(
              type: MaterialType.transparency,
              child: AnimatedContainer(
                duration: Motion.fast,
                curve: Motion.standard,
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.elevated
                      ? colors.surfaceElevated
                      : colors.surface,
                  borderRadius: Radii.card,
                  border: Border.all(
                    color: _hovered && interactive
                        ? colors.borderStrong
                        : colors.border,
                  ),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: _hovered ? 28 : 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: _hovered ? 20 : 12,
                            offset: Offset(0, _hovered ? 5 : 3),
                          ),
                        ],
                  gradient: widget.accent == null
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.accent!.withValues(
                              alpha: isDark ? 0.10 : 0.07,
                            ),
                            Colors.transparent,
                          ],
                        ),
                ),
                child: Stack(
                  children: [
                    if (widget.accent != null)
                      // A 3px accent rail down the left edge.
                      PositionedDirectional(
                        start: 0,
                        top: Insets.xl,
                        bottom: Insets.xl,
                        child: Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: widget.accent,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: widget.accent == null
                          ? EdgeInsets.zero
                          : const EdgeInsetsDirectional.only(start: Insets.md),
                      child: widget.child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small status pill.
///
/// The label is always present, so state is never communicated by colour alone.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.severity,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Severity severity;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = colors.forSeverity(severity);
    final background = colors.mutedForSeverity(severity);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Insets.sm : Insets.md,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Radii.pill,
        border: Border.all(color: foreground.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: foreground),
            SizedBox(width: dense ? 4 : 6),
          ],
          // Flexible so a badge squeezed into a narrow row ellipsizes rather
          // than overflowing its parent.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
                fontSize: dense ? 11 : 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card header with a title, an optional leading icon and a trailing status
/// widget.
///
/// Below roughly 260 logical pixels a trailing badge cannot sit beside the
/// title without either clipping or forcing the label to truncate to nonsense,
/// so the badge moves onto its own line instead. This is what keeps status
/// always readable rather than merely fitting.
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.titleStyle,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final TextStyle? titleStyle;

  /// Below this width the trailing widget is placed under the title.
  static const double stackBelowWidth = 260;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    final titleRow = Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: Insets.sm),
        ],
        Expanded(
          child: Text(
            title,
            style: titleStyle ?? theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (trailing == null) return titleRow;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < stackBelowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleRow,
              const SizedBox(height: Insets.sm),
              trailing!,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: titleRow),
            const SizedBox(width: Insets.md),
            trailing!,
          ],
        );
      },
    );
  }
}

/// A labelled section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: colors.textSecondary),
            const SizedBox(width: Insets.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Insets.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A compact metric readout.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.severity,
    this.icon,
    this.hint,
  });

  final String label;
  final String value;
  final String? unit;
  final Severity? severity;
  final IconData? icon;

  /// Long-form explanation, surfaced as a tooltip and to screen readers.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final valueColor = severity == null
        ? colors.textPrimary
        : colors.forSeverity(severity!);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: colors.textTertiary),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: valueColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(unit!, style: theme.textTheme.labelMedium),
            ],
          ],
        ),
      ],
    );

    if (hint == null) return content;
    return Tooltip(message: hint!, child: content);
  }
}

/// A responsive row of [MetricTile]s.
///
/// A plain [Row] of equal-width tiles looks tidy on a wide screen and breaks
/// on a narrow one: at 360dp with a large text scale, three tiles leave roughly
/// 80dp each, which is not enough for a value, a unit and a label. This wraps
/// instead of squeezing, so tiles reflow onto additional rows rather than
/// overflowing.
class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.tiles, this.minTileWidth = 132});

  final List<Widget> tiles;

  /// Tiles narrower than this wrap to the next line.
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        // Only wrap when there is genuinely not enough room; otherwise keep the
        // tidy single-row arrangement.
        final perRow = width <= 0
            ? 1
            : (width / minTileWidth).floor().clamp(1, tiles.length);

        if (perRow >= tiles.length) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: Insets.md),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }

        final tileWidth = (width - Insets.md * (perRow - 1)) / perRow;
        return Wrap(
          spacing: Insets.md,
          runSpacing: Insets.md,
          children: [
            for (final tile in tiles)
              SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

/// A friendly empty state with a clear next action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? Insets.xl : Insets.xxxl,
            horizontal: Insets.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  icon ?? Icons.inbox_outlined,
                  size: 24,
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: Insets.lg),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Insets.xl),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width notice used for warnings, errors and mode explanations.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.title,
    required this.message,
    required this.severity,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final Severity severity;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final foreground = colors.forSeverity(severity);
    final background = colors.mutedForSeverity(severity);

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: background,
          borderRadius: Radii.card,
          border: Border.all(color: foreground.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? _defaultIcon(severity), size: 18, color: foreground),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(message, style: theme.textTheme.bodySmall),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: Insets.md),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: foreground,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.md,
                          ),
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _defaultIcon(Severity severity) => switch (severity) {
    Severity.safe => Icons.check_circle_outline,
    Severity.info => Icons.info_outline,
    Severity.caution => Icons.warning_amber_rounded,
    Severity.critical => Icons.error_outline,
  };
}

/// A collapse/expand panel used for progressive disclosure of advanced
/// controls.
class AdvancedDisclosure extends StatefulWidget {
  const AdvancedDisclosure({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon = Icons.tune,
    this.initiallyOpen = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final IconData icon;
  final bool initiallyOpen;

  @override
  State<AdvancedDisclosure> createState() => _AdvancedDisclosureState();
}

class _AdvancedDisclosureState extends State<AdvancedDisclosure> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: Radii.card,
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                children: [
                  Icon(widget.icon, size: 17, color: colors.textSecondary),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: theme.textTheme.titleSmall),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: Motion.medium,
                    curve: Motion.standard,
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Motion.standard,
            secondCurve: Motion.standard,
            sizeCurve: Motion.standard,
            duration: Motion.medium,
            crossFadeState: _open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                0,
                Insets.lg,
                Insets.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(color: colors.border, height: 1),
                  const SizedBox(height: Insets.lg),
                  widget.child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled switch row used throughout Settings.
///
/// Built from an explicit [Row] rather than [SwitchListTile]: the tile variant
/// brings its own Material/ink assumptions and constrains the label in ways
/// that clip badly at large text scales, while a plain row with a trailing
/// [Switch] stays fully responsive and keeps the whole line tappable.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Semantics(
      toggled: value,
      label: title,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: Radii.control,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19, color: colors.textSecondary),
                  const SizedBox(width: Insets.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Insets.md),
                ExcludeSemantics(
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A read-only key/value row for detail panels.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor ?? theme.textTheme.bodyLarge?.color,
                fontFamily: monospace ? 'monospace' : null,
                fontSize: monospace ? 12.5 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation dialog for consequential actions.
///
/// Always requires an explicit choice and states the consequence in the body,
/// so destructive actions are never a single stray tap.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final colors = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            destructive ? Icons.warning_amber_rounded : Icons.help_outline,
            size: 20,
            color: destructive ? colors.critical : colors.textSecondary,
          ),
          const SizedBox(width: Insets.md),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: colors.critical,
                  foregroundColor: colors.isDark
                      ? const Color(0xFF2A0A0E)
                      : Colors.white,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
