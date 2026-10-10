import 'package:flutter/widgets.dart';

/// Spacing, radius, elevation and motion tokens shared by every widget.
///
/// Widgets must read values from here rather than sprinkling literal numbers,
/// so that density and rhythm stay consistent across the whole product.
abstract final class Insets {
  /// 2dp hairline, for gaps inside a single control.
  static const double xs = 4;

  /// 8dp, between related labels.
  static const double sm = 8;

  /// 12dp, standard gap inside a card.
  static const double md = 12;

  /// 16dp, card padding.
  static const double lg = 16;

  /// 20dp, gap between cards.
  static const double xl = 20;

  /// 24dp, section separation.
  static const double xxl = 24;

  /// 32dp, major section separation.
  static const double xxxl = 32;
}

/// Corner radii. Small controls use [sm], cards [md], panels and sheets [lg].
abstract final class Radii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;

  /// Fully rounded, for pills, badges and avatars.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius panel = BorderRadius.all(Radius.circular(lg));

  static const BorderRadius control =
      BorderRadius.all(Radius.circular(sm));
}

/// Animation durations. The product brief calls for 150-300ms transitions and
/// explicitly forbids bounce/elastic motion in engineering workflows, so every
/// curve here is a standard ease.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);

  /// Cross-fade used when the theme changes, so the switch reads as a fade
  /// rather than a hard cut.
  static const Duration themeFade = Duration(milliseconds: 260);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
  static const Curve decelerate = Curves.easeOut;
}

/// Minimum interactive target on touch platforms (Material accessibility
/// guidance). Desktop pointers may render smaller, but every tappable control
/// reserves at least this much hit area.
const double kMinTouchTarget = 48;

/// Width-based layout classes. Derived purely from available width, never from
/// `Platform.isAndroid` and friends, so a resized desktop window and a tablet
/// both reflow correctly.
enum LayoutSize {
  /// Phones in portrait. Bottom navigation, single column.
  compact,

  /// Large phones in landscape / small tablets. Two columns where useful.
  medium,

  /// Tablets and small desktop windows. Collapsed rail navigation.
  expanded,

  /// Wide desktop windows. Full sidebar, multi-column dashboards.
  large;

  bool get isCompact => this == LayoutSize.compact;
  bool get isMedium => this == LayoutSize.medium;
  bool get isExpanded => this == LayoutSize.expanded;
  bool get isLarge => this == LayoutSize.large;

  /// True when navigation should live in a side rail or sidebar rather than a
  /// bottom bar.
  bool get hasSideNavigation => this == LayoutSize.expanded || this == large;

  /// True when a collapsed icon rail is preferable to a labelled sidebar.
  bool get usesCollapsedRail => this == LayoutSize.expanded;
}

/// Breakpoints. Exposed for tests and for the shell's own assertions.
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1000;
  static const double large = 1360;

  static LayoutSize of(double width) {
    if (width < medium) return LayoutSize.compact;
    if (width < expanded) return LayoutSize.medium;
    if (width < large) return LayoutSize.expanded;
    return LayoutSize.large;
  }
}

/// Resolves the current [LayoutSize] for the nearest enclosing [MediaQuery].
extension LayoutSizeContext on BuildContext {
  LayoutSize get layoutSize =>
      Breakpoints.of(MediaQuery.sizeOf(this).width);
}