import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../data/app_settings.dart';
import '../components/mode_indicator.dart';

/// The primary navigation destinations.
///
/// The same enum drives the desktop sidebar, the tablet rail and the mobile
/// bottom bar, so all three form factors navigate identical routes and share
/// identical domain logic.
enum AppDestination {
  overview('Overview', Icons.dashboard_outlined, Icons.dashboard, '/'),
  accident('Accident Monitor', Icons.car_crash_outlined, Icons.car_crash, '/accident'),
  wearable('Wearable Monitor', Icons.watch_outlined, Icons.watch, '/wearable'),
  simulation('Simulation Lab', Icons.science_outlined, Icons.science, '/simulation'),
  devices('Device Manager', Icons.memory_outlined, Icons.memory, '/devices'),
  incidents('Incident History', Icons.history_outlined, Icons.history, '/incidents'),
  settings('Settings', Icons.settings_outlined, Icons.settings, '/settings');

  const AppDestination(this.label, this.icon, this.selectedIcon, this.route);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  /// The destinations that fit in a mobile bottom bar without becoming
  /// unreadable; the rest live behind More.
  static const List<AppDestination> bottomBarPrimary = <AppDestination>[
    overview,
    accident,
    simulation,
    incidents,
  ];
}

/// The desktop sidebar / tablet rail.
class AppNavigation extends StatelessWidget {
  const AppNavigation({
    super.key,
    required this.current,
    required this.onSelect,
    required this.mode,
    required this.onModeTap,
    this.collapsed = false,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final OperatingMode mode;
  final VoidCallback onModeTap;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Brand(collapsed: collapsed),
            const SizedBox(height: Insets.sm),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? Insets.sm : Insets.md,
              ),
              child: ModeIndicator(
                mode: mode,
                onTap: onModeTap,
                compact: collapsed,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? Insets.sm : Insets.sm,
                ),
                children: [
                  for (final destination in AppDestination.values)
                    _NavItem(
                      destination: destination,
                      selected: destination == current,
                      collapsed: collapsed,
                      onTap: () => onSelect(destination),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: collapsed
                  ? null
                  : Text(
                      'Smart Safety Ecosystem',
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.lg,
        Insets.lg,
        Insets.md,
      ),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.accent,
                  Color.lerp(colors.accent, colors.accentSecondary, 0.55)!,
                ],
              ),
            ),
            child: const Icon(
              Icons.shield_moon_outlined,
              size: 18,
              color: Color(0xFF04191C),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: Insets.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Smart Safety',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Ecosystem',
                    style: theme.textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
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

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final foreground =
        widget.selected ? colors.accent : colors.textSecondary;
    final background = widget.selected
        ? colors.accentMuted
        : (_hovered ? colors.surfaceAlt : Colors.transparent);

    final icon = Icon(
      widget.selected ? widget.destination.selectedIcon : widget.destination.icon,
      size: 19,
      color: foreground,
    );

    return Tooltip(
      message: widget.collapsed ? widget.destination.label : '',
      waitDuration: const Duration(milliseconds: 350),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Semantics(
            selected: widget.selected,
            button: true,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: Radii.control,
              child: AnimatedContainer(
                duration: Motion.fast,
                curve: Motion.standard,
                height: kMinTouchTarget,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : Insets.md,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: Radii.control,
                ),
                child: widget.collapsed
                    ? Center(child: icon)
                    : Row(
                        children: [
                          icon,
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Text(
                              widget.destination.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: foreground,
                                fontWeight: widget.selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
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

/// The compact top application bar.
///
/// Shows mode, connection state and the theme toggle on every form factor; the
/// title is dropped on narrow widths so the controls never overflow.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    required this.mode,
    required this.running,
    required this.onToggleRunning,
    required this.onThemeToggle,
    required this.onModeTap,
    this.actions = const <Widget>[],
    this.showMenu = false,
  });

  final String title;
  final OperatingMode mode;
  final bool running;
  final VoidCallback onToggleRunning;
  final VoidCallback onThemeToggle;
  final VoidCallback onModeTap;
  final List<Widget> actions;
  final bool showMenu;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return AppBar(
      toolbarHeight: 60,
      titleSpacing: Insets.xl,
      title: Text(title, style: theme.textTheme.titleLarge),
      actions: [
        for (final action in actions) action,
        IconButton(
          tooltip: running ? 'Pause live telemetry' : 'Start live telemetry',
          onPressed: onToggleRunning,
          icon: Icon(running ? Icons.pause_circle : Icons.play_circle),
        ),
        IconButton(
          tooltip: 'Switch theme',
          onPressed: onThemeToggle,
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Center(child: ModeIndicator(mode: mode, onTap: onModeTap)),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: colors.border),
      ),
    );
  }
}