import 'package:flutter/widgets.dart';

import 'app_navigation.dart';

/// Provides navigation to any descendant widget.
///
/// Screens need to move the user somewhere (the overview sends people to the
/// Simulation Lab, the history screen links to diagnostics). Passing a callback
/// through every constructor would be noise, and reaching into ancestor state
/// directly would bypass the shell's own bookkeeping, so navigation is exposed
/// through an inherited widget instead.
class NavigationScope extends InheritedWidget {
  const NavigationScope({
    super.key,
    required this.select,
    required this.current,
    required super.child,
  });

  final ValueChanged<AppDestination> select;
  final AppDestination current;

  /// Navigates to [destination].
  static void go(BuildContext context, AppDestination destination) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NavigationScope>();
    assert(scope != null, 'No NavigationScope found in the widget tree');
    scope?.select(destination);
  }

  @override
  bool updateShouldNotify(NavigationScope oldWidget) =>
      current != oldWidget.current || select != oldWidget.select;
}