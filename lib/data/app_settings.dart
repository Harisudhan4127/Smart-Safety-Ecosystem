import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/accident_detector.dart';
import '../domain/awtra.dart';

/// The three theme choices offered in Settings.
enum AppThemePreference {
  light('Light'),
  dark('Dark'),
  system('System');

  const AppThemePreference(this.label);

  final String label;

  ThemeMode get themeMode => switch (this) {
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
        AppThemePreference.system => ThemeMode.system,
      };

  static AppThemePreference fromName(String? name) =>
      AppThemePreference.values.firstWhere(
        (t) => t.name == name,
        // Light is the documented default on a fresh installation.
        orElse: () => AppThemePreference.light,
      );
}

/// Demo Mode or Real Hardware Mode.
enum OperatingMode {
  demo('Demo Mode', 'Simulated data. No devices or network required.'),
  hardware('Real Hardware', 'Live data from connected devices.');

  const OperatingMode(this.label, this.description);

  final String label;
  final String description;

  bool get isDemo => this == OperatingMode.demo;
  bool get isHardware => this == OperatingMode.hardware;

  static OperatingMode fromName(String? name) => OperatingMode.values
      .firstWhere((m) => m.name == name, orElse: () => OperatingMode.demo);
}

/// User-controlled application settings.
///
/// Threshold calibration lives here so it persists, but the UI only exposes it
/// behind the Advanced toggle and always pairs an edit with its consequences.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  static const String _kTheme = 'settings.theme';
  static const String _kMode = 'settings.mode';
  static const String _kSeenWelcome = 'settings.seenWelcome';
  static const String _kAdvanced = 'settings.advancedMode';
  static const String _kAwtra = 'settings.awtra';
  static const String _kThresholds = 'settings.thresholds';
  static const String _kSmsArmed = 'settings.notificationsArmed';
  static const String _kDemoScenario = 'settings.demoScenario';
  static const String _kDemoSpeed = 'settings.demoSpeed';
  static const String _kNotifications = 'settings.notificationsEnabled';

  static Future<AppSettings> load() async =>
      AppSettings(await SharedPreferences.getInstance());

  AppThemePreference get themePreference =>
      AppThemePreference.fromName(_prefs.getString(_kTheme));

  /// Default: [AppThemePreference.light].
  Future<void> setThemePreference(AppThemePreference value) async {
    await _prefs.setString(_kTheme, value.name);
    notifyListeners();
  }

  OperatingMode get mode => OperatingMode.fromName(_prefs.getString(_kMode));

  /// Default: [OperatingMode.demo], which is safe because it cannot contact
  /// any real emergency service.
  Future<void> setMode(OperatingMode value) async {
    await _prefs.setString(_kMode, value.name);
    notifyListeners();
  }

  bool get hasSeenWelcome => _prefs.getBool(_kSeenWelcome) ?? false;

  Future<void> markWelcomeSeen() async {
    await _prefs.setBool(_kSeenWelcome, true);
    notifyListeners();
  }

  /// Whether the Advanced toggle is engaged on this device.
  bool get advancedMode => _prefs.getBool(_kAdvanced) ?? false;

  Future<void> setAdvancedMode(bool value) async {
    await _prefs.setBool(_kAdvanced, value);
    notifyListeners();
  }

  AwtraConfig get awtra {
    final raw = _prefs.getString(_kAwtra);
    if (raw == null) return const AwtraConfig();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AwtraConfig.fromJson(decoded);
    } on Object {
      // Fall through to defaults rather than failing to start.
    }
    return const AwtraConfig();
  }

  Future<void> setAwtra(AwtraConfig value) async {
    await _prefs.setString(_kAwtra, jsonEncode(value.toJson()));
    notifyListeners();
  }

  AccidentThresholds get thresholds {
    final raw = _prefs.getString(_kThresholds);
    if (raw == null) return const AccidentThresholds();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AccidentThresholds.fromJson(decoded);
      }
    } on Object {
      // Fall through to defaults.
    }
    return const AccidentThresholds();
  }

  Future<void> setThresholds(AccidentThresholds value) async {
    await _prefs.setString(_kThresholds, jsonEncode(value.toJson()));
    notifyListeners();
  }

  /// Whether in-app banners for new incidents are shown.
  bool get notificationsEnabled => _prefs.getBool(_kNotifications) ?? true;

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool(_kNotifications, value);
    notifyListeners();
  }

  /// Whether external notification services are armed.
  ///
  /// Real external dispatch (SMS to a hospital, for example) requires separate
  /// authorisation and is never enabled by the app on its own. This flag is
  /// false on a fresh install.
  bool get externalNotificationsArmed =>
      _prefs.getBool(_kSmsArmed) ?? false;

  Future<void> setExternalNotificationsArmed(bool value) async {
    await _prefs.setBool(_kSmsArmed, value);
    notifyListeners();
  }

  String get demoScenarioId =>
      _prefs.getString(_kDemoScenario) ?? 'impact-rear-end';

  Future<void> setDemoScenario(String id) async {
    await _prefs.setString(_kDemoScenario, id);
    notifyListeners();
  }

  /// Playback speed multiplier for the simulation lab.
  double get demoSpeed => _prefs.getDouble(_kDemoSpeed) ?? 1.0;

  Future<void> setDemoSpeed(double value) async {
    await _prefs.setDouble(_kDemoSpeed, value);
    notifyListeners();
  }

  /// Restores every setting to its documented default. Theme returns to Light.
  Future<void> resetToDefaults() async {
    await _prefs.remove(_kAwtra);
    await _prefs.remove(_kThresholds);
    await _prefs.remove(_kSmsArmed);
    await _prefs.remove(_kDemoScenario);
    await _prefs.remove(_kDemoSpeed);
    await _prefs.remove(_kAdvanced);
    await _prefs.setString(_kTheme, AppThemePreference.light.name);
    await _prefs.setString(_kMode, OperatingMode.demo.name);
    notifyListeners();
  }
}