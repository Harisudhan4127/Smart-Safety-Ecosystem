import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';
import '../../data/app_settings.dart';
import '../../state/app_controller.dart';
import '../components/mode_indicator.dart';
import '../components/surface_card.dart';
import '../screens/about_screen.dart';
import '../screens/accident_monitor_screen.dart';
import '../screens/device_manager_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/incident_history_screen.dart';
import '../screens/overview_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/simulation_lab_screen.dart';
import '../screens/wearable_monitor_screen.dart';
import 'app_navigation.dart';
import 'navigation_scope.dart';

/// The adaptive application shell.
///
/// One shell serves all three form factors. The layout class comes from the
/// available width, not from the platform, so resizing a desktop window and
/// rotating a tablet both reflow correctly:
///
/// * compact/medium -> bottom navigation bar
/// * expanded      -> collapsed icon rail
/// * large         -> full labelled sidebar
///
/// All form factors share the same routes and the same [AppController], so no
/// domain logic is duplicated per platform.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppDestination _destination = AppDestination.overview;
  bool _sidebarCollapsed = false;

  AppController get _controller => widget.controller;

  void _select(AppDestination destination) =>
      setState(() => _destination = destination);

  /// Toggles between the labelled sidebar and the collapsed rail.
  void _toggleSidebar() {
    if (!context.layoutSize.isLarge) return;
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  Future<void> _cycleTheme() async {
    final settings = _controller.settings;
    final next = switch (settings.themePreference) {
      AppThemePreference.light => AppThemePreference.dark,
      AppThemePreference.dark => AppThemePreference.system,
      AppThemePreference.system => AppThemePreference.light,
    };
    await settings.setThemePreference(next);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Theme: ${next.label}'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _openModeSwitcher() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ModeSwitchSheet(controller: _controller),
    );
  }

  Future<void> _openMoreSheet() async {
    final selected = await showModalBottomSheet<AppDestination>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MoreSheet(current: _destination),
    );
    if (selected != null) _select(selected);
  }

  Widget _screenFor(AppDestination destination) => switch (destination) {
        AppDestination.overview => OverviewScreen(controller: _controller),
        AppDestination.accident =>
          AccidentMonitorScreen(controller: _controller),
        AppDestination.wearable =>
          WearableMonitorScreen(controller: _controller),
        AppDestination.simulation =>
          SimulationLabScreen(controller: _controller),
        AppDestination.devices => DeviceManagerScreen(controller: _controller),
        AppDestination.incidents =>
          IncidentHistoryScreen(controller: _controller),
        AppDestination.settings => SettingsScreen(controller: _controller),
      };

  @override
  Widget build(BuildContext context) {
    final layout = context.layoutSize;
    final useBottomNav = !layout.hasSideNavigation;

    return NavigationScope(
      select: _select,
      current: _destination,
      child: Scaffold(
      appBar: AppTopBar(
        title: _destination.label,
        mode: _controller.mode,
        running: _controller.isRunning,
        onToggleRunning: _controller.toggleRunning,
        onThemeToggle: _cycleTheme,
        onModeTap: _openModeSwitcher,
        actions: [
          if (layout.isLarge)
            IconButton(
              tooltip: _sidebarCollapsed
                  ? 'Expand navigation'
                  : 'Collapse navigation',
              onPressed: _toggleSidebar,
              icon: Icon(
                _sidebarCollapsed
                    ? Icons.menu_open_outlined
                    : Icons.menu_open_rounded,
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: layout.hasSideNavigation
            ? Row(
                children: [
                  SizedBox(
                    width: _sidebarCollapsed ? 68 : 236,
                    child: AppNavigation(
                      current: _destination,
                      onSelect: _select,
                      mode: _controller.mode,
                      onModeTap: _openModeSwitcher,
                      collapsed: _sidebarCollapsed,
                    ),
                  ),
                  Expanded(
                    child: _PageHost(
                      key: ValueKey(_destination),
                      destination: _destination,
                      child: _screenFor(_destination),
                    ),
                  ),
                ],
              )
            : _PageHost(
                key: ValueKey(_destination),
                destination: _destination,
                child: _screenFor(_destination),
              ),
      ),
      bottomNavigationBar: useBottomNav
          ? _MobileNavigation(
              current: _destination,
              onSelect: _select,
              onMore: _openMoreSheet,
              openIncidentCount: _controller.openIncidentCount,
            )
          : null,
      ),
    );
  }
}

/// Wraps each screen so navigation changes animate rather than snap.
///
/// The transition is horizontal on wide layouts (matching the direction of a
/// sidebar) and vertical on narrow ones (matching a bottom bar). Both are short
/// fades with a small offset; nothing bounces.
class _PageHost extends StatelessWidget {
  const _PageHost({
    super.key,
    required this.destination,
    required this.child,
  });

  final AppDestination destination;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final horizontal = context.layoutSize.hasSideNavigation;
    return AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.standard,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(horizontal ? 0.02 : 0, horizontal ? 0 : 0.015),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: <Widget>[...previous, ?current],
      ),
      child: child,
    );
  }
}

/// Bottom navigation for compact and medium layouts.
class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.current,
    required this.onSelect,
    required this.onMore,
    required this.openIncidentCount,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final VoidCallback onMore;
  final int openIncidentCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const bar = AppDestination.bottomBarPrimary;
    // Anything not in the bottom bar is represented by the More entry, which
    // keeps the selection indicator in sync with the visible destinations.
    final barIndex = bar.indexOf(current);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: NavigationBar(
        selectedIndex: barIndex >= 0 ? barIndex : bar.length,
        onDestinationSelected: (index) {
          if (index == 4) {
            onMore();
            return;
          }
          onSelect(AppDestination.bottomBarPrimary[index]);
        },
        destinations: [
          for (final destination in AppDestination.bottomBarPrimary)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label.split(' ').first,
            ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: openIncidentCount > 0,
              label: Text('$openIncidentCount'),
              child: const Icon(Icons.more_horiz),
            ),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

/// The "More" sheet listing the destinations that do not fit in the bottom bar,
/// plus the secondary pages.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.current});

  final AppDestination current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final secondary = <({String label, IconData icon, Widget page})>[
      (
        label: 'System diagnostics',
        icon: Icons.monitor_heart_outlined,
        page: const DiagnosticsScreen(),
      ),
      (
        label: 'About this application',
        icon: Icons.info_outline,
        page: const AboutScreen(),
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                0,
                Insets.xl,
                Insets.md,
              ),
              child: Text('More', style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Column(
                children: [
                  for (final destination in AppDestination.values)
                    if (!AppDestination.bottomBarPrimary.contains(destination))
                      ListTile(
                        leading: Icon(destination.icon),
                        title: Text(destination.label),
                        selected: destination == current,
                        selectedTileColor: context.colors.accentMuted,
                        onTap: () =>
                            Navigator.of(context).pop(destination),
                      ),
                ],
              ),
            ),
            const Divider(height: Insets.xxl),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                0,
                Insets.xl,
                Insets.md,
              ),
              child: Text('Secondary', style: theme.textTheme.labelMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                0,
                Insets.md,
                Insets.lg,
              ),
              child: Column(
                children: [
                  for (final entry in secondary)
                    ListTile(
                      leading: Icon(entry.icon),
                      title: Text(entry.label),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => entry.page),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mode switching, which always requires an explicit confirmation.
class _ModeSwitchSheet extends StatefulWidget {
  const _ModeSwitchSheet({required this.controller});

  final AppController controller;

  @override
  State<_ModeSwitchSheet> createState() => _ModeSwitchSheetState();
}

class _ModeSwitchSheetState extends State<_ModeSwitchSheet> {
  late OperatingMode _pending = widget.controller.mode;

  Future<void> _confirm() async {
    final settings = widget.controller.settings;
    final target = _pending;
    final navigator = Navigator.of(context);

    if (target == settings.mode) {
      navigator.pop();
      return;
    }

    // Real Hardware Mode changes what the app is allowed to do, so it always
    // confirms. Demo Mode also confirms, since leaving it can stop a running
    // simulation.
    final movingToHardware = target.isHardware;
    final accepted = await confirmAction(
      context,
      title: movingToHardware
          ? 'Switch to Real Hardware Mode?'
          : 'Switch to Demo Mode?',
      message: movingToHardware
          ? 'The app will read live data from connected devices. Anything not '
              'connected is reported as unavailable \u2014 the app will not '
              'substitute simulated readings. External notifications stay off '
              'until you authorise them separately.'
          : 'The app will use scripted data. No device, radio or network '
              'connection is used, and no real emergency call can be made.',
      confirmLabel: movingToHardware ? 'Switch to Real Hardware' : 'Switch to Demo',
    );

    if (!accepted) return;

    await settings.setMode(target);
    widget.controller.setRunning(false);
    if (target.isDemo) {
      widget.controller.resetSimulation();
    } else {
      widget.controller.rearmDetector();
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          0,
          Insets.xl,
          Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Operating mode', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Choose what the app is allowed to do.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.lg),
            ModeSelectorCard(
              mode: OperatingMode.demo,
              selected: _pending.isDemo,
              onSelect: (mode) => setState(() => _pending = mode),
            ),
            const SizedBox(height: Insets.md),
            ModeSelectorCard(
              mode: OperatingMode.hardware,
              selected: _pending.isHardware,
              onSelect: (mode) => setState(() => _pending = mode),
            ),
            const SizedBox(height: Insets.xl),
            FilledButton(
              onPressed: _confirm,
              child: Text(
                _pending == widget.controller.mode
                    ? 'Keep current mode'
                    : 'Switch mode',
              ),
            ),
            const SizedBox(height: Insets.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps screen content with the standard adaptive page padding.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.maxWidth = 1400,
    this.scrollable = true,
  });

  final List<Widget> children;
  final double maxWidth;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final layout = context.layoutSize;

    // Padding grows with the viewport so content never hugs the window edge on
    // a wide monitor, and stays comfortable on a phone.
    final horizontal = switch (layout) {
      LayoutSize.compact => Insets.lg,
      LayoutSize.medium => Insets.xl,
      _ => Insets.xxxl,
    };
    final vertical = switch (layout) {
      LayoutSize.compact => Insets.lg,
      _ => Insets.xl,
    };

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    if (scrollable) {
      content = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(horizontal, vertical, horizontal, 64),
        child: content,
      );
    } else {
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
        child: content,
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}