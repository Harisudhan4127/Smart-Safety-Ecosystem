import 'package:flutter/material.dart';

import 'core/design/app_theme.dart';
import 'data/app_settings.dart';
import 'data/incident_store.dart';
import 'state/app_controller.dart';
import 'ui/shell/app_shell.dart';

/// Application entry point.
///
/// Settings and the incident log are loaded before the first frame so the app
/// never flashes the wrong theme, and so the persisted theme is applied on the
/// very first paint rather than after a visible transition.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await AppSettings.load();
  final incidentStore = IncidentStore();

  // A corrupt log must not stop the application from starting.
  await incidentStore.load();

  final controller = AppController(
    settings: settings,
    incidentStore: incidentStore,
  );

  runApp(SmartSafetyApp(controller: controller));
}

class SmartSafetyApp extends StatelessWidget {
  const SmartSafetyApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.settings,
      builder: (context, _) {
        final preference = controller.settings.themePreference;

        return MaterialApp(
          title: 'Smart Safety Ecosystem',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          // 'System' is honoured by the framework; an explicit Light or Dark
          // choice overrides it and persists across restarts.
          themeMode: preference.themeMode,
          home: AppShell(controller: controller),
          builder: (context, child) {
            // Clamp text scaling so an extreme accessibility setting cannot
            // break the control layout, while still honouring a wide range.
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: media.textScaler.clamp(
                  minScaleFactor: 0.85,
                  maxScaleFactor: 1.6,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
