import 'package:flutter/material.dart';

import '../../domain/models/severity.dart';
import 'tokens.dart';

/// Semantic colour tokens that sit alongside Material's [ColorScheme].
///
/// Widgets read from this extension instead of hard-coding colours, which is
/// what allows a single widget implementation to render correctly in both the
/// light and the premium dark theme.
///
/// Light values follow the airy, neutral product palette. Dark values are the
/// graphite/charcoal system: layered near-black surfaces with restrained
/// luminance steps, teal and periwinkle accents, and no pure black anywhere.
@immutable
class SseColors extends ThemeExtension<SseColors> {
  const SseColors({
    required this.brightness,
    required this.surfaceSunken,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSecondary,
    required this.onAccent,
    required this.accentMuted,
    required this.success,
    required this.warning,
    required this.critical,
    required this.info,
    required this.successMuted,
    required this.warningMuted,
    required this.criticalMuted,
    required this.infoMuted,
    required this.demoAccent,
    required this.demoAccentMuted,
    required this.chartGrid,
    required this.shadow,
    required this.highlight,
    required this.sheen,
    required this.overlayScrim,
  });

  final Brightness brightness;

  /// The window background behind all cards.
  final Color surfaceSunken;

  /// Default card / panel background.
  final Color surface;

  /// Secondary fill used for inner blocks, table stripes and input fields.
  final Color surfaceAlt;

  /// Background for elements that sit above [surface] (menus, sheets, popovers).
  final Color surfaceElevated;

  final Color border;

  /// A slightly stronger border for emphasis (selected or focused rows).
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;

  /// De-emphasised text for units, captions and metadata. Still meets 4.5:1
  /// against [surface] in both themes.
  final Color textTertiary;

  final Color accent;
  final Color accentSecondary;

  /// Foreground colour that meets contrast on top of [accent].
  final Color onAccent;

  /// Low-intensity accent fill for chips and selected-row backgrounds.
  final Color accentMuted;

  final Color success;
  final Color warning;
  final Color critical;
  final Color info;

  final Color successMuted;
  final Color warningMuted;
  final Color criticalMuted;
  final Color infoMuted;

  /// Demo Mode is always teal-leaning and always paired with a "SIMULATED"
  /// glyph, so mode is never communicated by colour alone.
  final Color demoAccent;
  final Color demoAccentMuted;

  /// Chart gridlines. Deliberately very low contrast in the dark theme.
  final Color chartGrid;

  final Color shadow;

  /// A 1px light edge used to give dark surfaces a machined-metal lip.
  final Color highlight;

  /// A very subtle top-down gradient used on prominent dark surfaces to
  /// suggest a light source without glassmorphism.
  final Gradient sheen;

  final Color overlayScrim;

  bool get isDark => brightness == Brightness.dark;

  /// Maps a semantic severity to its foreground colour. Severity is always
  /// accompanied by an icon and text elsewhere, so this is never the sole
  /// carrier of meaning.
  Color forSeverity(Severity severity) => switch (severity) {
        Severity.safe => success,
        Severity.info => info,
        Severity.caution => warning,
        Severity.critical => critical,
      };

  Color mutedForSeverity(Severity severity) => switch (severity) {
        Severity.safe => successMuted,
        Severity.info => infoMuted,
        Severity.caution => warningMuted,
        Severity.critical => criticalMuted,
      };

  @override
  SseColors copyWith({
    Brightness? brightness,
    Color? surfaceSunken,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceElevated,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentSecondary,
    Color? onAccent,
    Color? accentMuted,
    Color? success,
    Color? warning,
    Color? critical,
    Color? info,
    Color? successMuted,
    Color? warningMuted,
    Color? criticalMuted,
    Color? infoMuted,
    Color? demoAccent,
    Color? demoAccentMuted,
    Color? chartGrid,
    Color? shadow,
    Color? highlight,
    Gradient? sheen,
    Color? overlayScrim,
  }) {
    return SseColors(
      brightness: brightness ?? this.brightness,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      onAccent: onAccent ?? this.onAccent,
      accentMuted: accentMuted ?? this.accentMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      critical: critical ?? this.critical,
      info: info ?? this.info,
      successMuted: successMuted ?? this.successMuted,
      warningMuted: warningMuted ?? this.warningMuted,
      criticalMuted: criticalMuted ?? this.criticalMuted,
      infoMuted: infoMuted ?? this.infoMuted,
      demoAccent: demoAccent ?? this.demoAccent,
      demoAccentMuted: demoAccentMuted ?? this.demoAccentMuted,
      chartGrid: chartGrid ?? this.chartGrid,
      shadow: shadow ?? this.shadow,
      highlight: highlight ?? this.highlight,
      sheen: sheen ?? this.sheen,
      overlayScrim: overlayScrim ?? this.overlayScrim,
    );
  }

  @override
  SseColors lerp(ThemeExtension<SseColors>? other, double t) {
    if (other is! SseColors) return this;
    return SseColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      info: Color.lerp(info, other.info, t)!,
      successMuted: Color.lerp(successMuted, other.successMuted, t)!,
      warningMuted: Color.lerp(warningMuted, other.warningMuted, t)!,
      criticalMuted: Color.lerp(criticalMuted, other.criticalMuted, t)!,
      infoMuted: Color.lerp(infoMuted, other.infoMuted, t)!,
      demoAccent: Color.lerp(demoAccent, other.demoAccent, t)!,
      demoAccentMuted:
          Color.lerp(demoAccentMuted, other.demoAccentMuted, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      sheen: Gradient.lerp(sheen, other.sheen, t)!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
    );
  }
}

/// Convenience accessor so widgets can write `context.colors.accent`.
extension SseColorsX on BuildContext {
  SseColors get colors => Theme.of(this).extension<SseColors>()!;
}

abstract final class AppTheme {
  static const String _fontFamily = 'Inter';

  static const SseColors _light = SseColors(
    brightness: Brightness.light,
    surfaceSunken: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF2F6),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFDCE3EB),
    borderStrong: Color(0xFFBFCBDA),
    textPrimary: Color(0xFF172033),
    textSecondary: Color(0xFF64748B),
    textTertiary: Color(0xFF8494A8),
    accent: Color(0xFF087F8C),
    accentSecondary: Color(0xFF3563E9),
    onAccent: Color(0xFFFFFFFF),
    accentMuted: Color(0x1F087F8C),
    success: Color(0xFF21845B),
    warning: Color(0xFFB7791F),
    critical: Color(0xFFC43D4B),
    info: Color(0xFF3563E9),
    successMuted: Color(0x1F21845B),
    warningMuted: Color(0x24B7791F),
    criticalMuted: Color(0x24C43D4B),
    infoMuted: Color(0x1F3563E9),
    demoAccent: Color(0xFF087F8C),
    demoAccentMuted: Color(0x1A087F8C),
    chartGrid: Color(0xFFE7ECF2),
    shadow: Color(0x14172033),
    highlight: Color(0xFFFFFFFF),
    sheen: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    ),
    overlayScrim: Color(0x66172033),
  );

  static const SseColors _dark = SseColors(
    brightness: Brightness.dark,
    // Graphite ladder. Not pure black: the deepest surface is #0B0D10 so that
    // elevation reads as luminance rather than as an absence of light.
    surfaceSunken: Color(0xFF0B0D10),
    surface: Color(0xFF12161C),
    surfaceAlt: Color(0xFF1A2029),
    surfaceElevated: Color(0xFF222A35),
    border: Color(0xFF2B3440),
    borderStrong: Color(0xFF3C4856),
    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFFA4AFBD),
    textTertiary: Color(0xFF7D8A9B),
    accent: Color(0xFF49D6C5),
    accentSecondary: Color(0xFF8BA8FF),
    onAccent: Color(0xFF04191C),
    accentMuted: Color(0x2449D6C5),
    success: Color(0xFF49C58A),
    warning: Color(0xFFF0BD5B),
    critical: Color(0xFFFF6474),
    info: Color(0xFF8BA8FF),
    successMuted: Color(0x1F49C58A),
    warningMuted: Color(0x26F0BD5B),
    criticalMuted: Color(0x26FF6474),
    infoMuted: Color(0x248BA8FF),
    demoAccent: Color(0xFF49D6C5),
    demoAccentMuted: Color(0x2449D6C5),
    chartGrid: Color(0xFF1E252E),
    shadow: Color(0x8C000000),
    // A cool metallic lip: this single 1px highlight is what gives dark cards
    // their machined, premium edge without resorting to glow or blur.
    highlight: Color(0xFF39434F),
    sheen: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
    ),
    overlayScrim: Color(0x99000000),
  );

  static ThemeData get light => _build(_light, Brightness.light);

  static ThemeData get dark => _build(_dark, Brightness.dark);

  static ThemeData _build(SseColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentMuted,
      onPrimaryContainer: c.textPrimary,
      secondary: c.accentSecondary,
      onSecondary: c.onAccent,
      secondaryContainer: c.infoMuted,
      onSecondaryContainer: c.textPrimary,
      tertiary: c.success,
      onTertiary: c.onAccent,
      tertiaryContainer: c.successMuted,
      onTertiaryContainer: c.textPrimary,
      error: c.critical,
      onError: brightness == Brightness.dark
          ? const Color(0xFF2A0A0E)
          : const Color(0xFFFFFFFF),
      errorContainer: c.criticalMuted,
      onErrorContainer: c.textPrimary,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surfaceSunken,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surfaceAlt,
      surfaceContainerHigh: c.surfaceElevated,
      surfaceContainerHighest: c.surfaceElevated,
      surfaceBright: c.surface,
      surfaceDim: c.surfaceSunken,
      outline: c.border,
      outlineVariant: c.border,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.surfaceSunken,
      inversePrimary: c.accentSecondary,
      shadow: c.shadow,
      scrim: c.overlayScrim,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: c.surfaceSunken,
      canvasColor: c.surface,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: _textTheme(base.textTheme, c),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: c.textPrimary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 20),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Radii.card),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.surfaceAlt,
          disabledForegroundColor: c.textTertiary,
          minimumSize: const Size(0, kMinTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          shape: const RoundedRectangleBorder(
            borderRadius: Radii.control,
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(0, kMinTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          side: BorderSide(color: c.border),
          shape: const RoundedRectangleBorder(
            borderRadius: Radii.control,
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            letterSpacing: -0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(0, kMinTouchTarget),
          shape: const RoundedRectangleBorder(
            borderRadius: Radii.control,
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
      ),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size(0, kMinTouchTarget - 6),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.onAccent
              : c.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent
              : c.surfaceAlt,
        ),
        trackOutlineColor:
            WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent
              : c.border,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.surfaceAlt,
        thumbColor: c.accent,
        overlayColor: c.accentMuted,
        trackHeight: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 14),
        hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 14),
        prefixIconColor: c.textTertiary,
        suffixIconColor: c.textTertiary,
        border: const OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: Colors.transparent),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: c.critical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: c.critical, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accentMuted,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? c.accent
                : c.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? c.accent
                : c.textSecondary,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.panel),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: c.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          height: 1.45,
          color: c.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 4),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 8),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0xFF2C3644) : const Color(0xFF1F2937),
          borderRadius: Radii.control,
          border: Border.all(color: c.isDark ? c.highlight : Colors.transparent),
        ),
        textStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12.5,
          height: 1.35,
          color: c.isDark ? c.textPrimary : const Color(0xFFF5F7FA),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.isDark ? c.surfaceElevated : const Color(0xFF1B2430),
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: c.isDark ? c.textPrimary : const Color(0xFFF5F7FA),
        ),
        actionTextColor: c.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.control),
        insetPadding: const EdgeInsets.all(Insets.lg),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        shape: const RoundedRectangleBorder(borderRadius: Radii.control),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceAlt,
        selectedColor: c.accentMuted,
        side: BorderSide(color: c.border),
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Radii.pill),
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceAlt,
        circularTrackColor: c.surfaceAlt,
        linearMinHeight: 6,
      ),
      focusColor: c.accentMuted,
      visualDensity: VisualDensity.standard,
    );
  }

  /// A typographic scale with tightened tracking on large sizes, which is what
  /// separates "premium" from "default Material".
  static TextTheme _textTheme(TextTheme base, SseColors c) {
    TextStyle s(
      double size,
      FontWeight weight,
      Color color, {
      double spacing = 0,
      double height = 1.4,
    }) =>
        TextStyle(
          fontFamily: _fontFamily,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          height: height,
          color: color,
        );

    return base.copyWith(
      displayLarge: s(40, FontWeight.w700, c.textPrimary, spacing: -1.0),
      displayMedium: s(32, FontWeight.w700, c.textPrimary, spacing: -0.8),
      displaySmall: s(26, FontWeight.w600, c.textPrimary, spacing: -0.6),
      headlineMedium: s(22, FontWeight.w600, c.textPrimary, spacing: -0.4),
      headlineSmall: s(19, FontWeight.w600, c.textPrimary, spacing: -0.3),
      titleLarge: s(17, FontWeight.w600, c.textPrimary, spacing: -0.2),
      titleMedium:
          s(15, FontWeight.w600, c.textPrimary, spacing: -0.1, height: 1.3),
      titleSmall: s(13.5, FontWeight.w600, c.textPrimary, height: 1.3),
      bodyLarge: s(15, FontWeight.w400, c.textPrimary, height: 1.5),
      bodyMedium: s(14, FontWeight.w400, c.textSecondary, height: 1.5),
      bodySmall: s(12.5, FontWeight.w400, c.textSecondary, height: 1.45),
      labelLarge: s(14, FontWeight.w600, c.textPrimary),
      labelMedium:
          s(12.5, FontWeight.w500, c.textSecondary, spacing: 0.1),
      labelSmall: s(11.5, FontWeight.w500, c.textTertiary, spacing: 0.3),
    );
  }
}