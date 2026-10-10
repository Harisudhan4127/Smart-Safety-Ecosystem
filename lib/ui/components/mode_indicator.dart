import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../data/app_settings.dart';

/// The operating-mode indicator.
///
/// Demo and Real Hardware are distinguished by **three** redundant signals:
/// a distinct icon, an explicit word ("Simulated" / "Live"), and colour. That
/// satisfies the requirement that mode is never communicated by colour alone,
/// and keeps it unambiguous for colour-blind users and in grayscale print.
class ModeIndicator extends StatelessWidget {
  const ModeIndicator({
    super.key,
    required this.mode,
    this.onTap,
    this.compact = false,
  });

  final OperatingMode mode;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final isDemo = mode.isDemo;

    final foreground =
        isDemo ? colors.demoAccent : (colors.isDark ? colors.success : colors.success);
    final background = isDemo ? colors.demoAccentMuted : colors.successMuted;

    final label = isDemo ? 'Simulated' : 'Live';
    final semanticLabel =
        isDemo ? 'Demo Mode, data is simulated' : 'Real Hardware Mode, live data';

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Insets.sm : Insets.md,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Radii.pill,
        border: Border.all(color: foreground.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDemo ? Icons.science_outlined : Icons.sensors,
            size: compact ? 12 : 14,
            color: foreground,
          ),
          const SizedBox(width: 5),
          // Flexible so the label shrinks instead of overflowing when the text
          // scale is large or the pill sits in a narrow slot.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (compact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                      ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(label: semanticLabel, child: content);
    }

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Tooltip(
        message: isDemo
            ? 'Demo Mode uses scripted data. No device or network is used.'
            : 'Real Hardware Mode reads live data from connected devices.',
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.pill,
          child: content,
        ),
      ),
    );
  }
}

/// A larger mode card used on the welcome screen and in Settings, which
/// explains what each mode actually does before the user commits to one.
class ModeSelectorCard extends StatelessWidget {
  const ModeSelectorCard({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSelect,
  });

  final OperatingMode mode;
  final bool selected;
  final ValueChanged<OperatingMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final isDemo = mode.isDemo;

    return Semantics(
      selected: selected,
      button: true,
      label: '${mode.label}. ${mode.description}',
      child: InkWell(
        onTap: () => onSelect(mode),
        borderRadius: Radii.card,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.standard,
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: selected
                ? (isDemo ? colors.demoAccentMuted : colors.successMuted)
                : colors.surface,
            borderRadius: Radii.card,
            border: Border.all(
              color: selected
                  ? (isDemo ? colors.demoAccent : colors.success)
                  : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isDemo ? Icons.science_outlined : Icons.sensors,
                size: 20,
                color: selected
                    ? (isDemo ? colors.demoAccent : colors.success)
                    : colors.textTertiary,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Flexible so a long mode name ellipsizes instead of
                        // pushing the selected marker out of the card.
                        Flexible(
                          child: Text(
                            mode.label,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        if (selected)
                          Icon(
                            Icons.check_circle,
                            size: 15,
                            color: isDemo
                                ? colors.demoAccent
                                : colors.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(mode.description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}