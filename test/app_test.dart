import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_safety_ecosystem/core/design/app_theme.dart';
import 'package:smart_safety_ecosystem/core/design/tokens.dart';
import 'package:smart_safety_ecosystem/data/app_settings.dart';
import 'package:smart_safety_ecosystem/data/incident_store.dart';
import 'package:smart_safety_ecosystem/domain/models/incident.dart';
import 'package:smart_safety_ecosystem/domain/models/severity.dart';
import 'package:smart_safety_ecosystem/main.dart';
import 'package:smart_safety_ecosystem/state/app_controller.dart';
import 'package:smart_safety_ecosystem/ui/components/mode_indicator.dart';
import 'package:smart_safety_ecosystem/ui/screens/about_screen.dart';

/// Builds the real application against an in-memory preference store and a
/// temporary incident store, so the widget tests exercise production wiring
/// rather than a hand-assembled harness.
Future<AppController> buildController({Map<String, Object>? initial}) async {
  SharedPreferences.setMockInitialValues(initial ?? <String, Object>{});
  final settings = await AppSettings.load();
  return AppController(
    settings: settings,
    incidentStore: IncidentStore(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('theme defaults', () {
    test('a fresh install starts in Light mode', () async {
      final controller = await buildController();
      expect(
        controller.settings.themePreference,
        AppThemePreference.light,
        reason: 'Light is the documented default on first launch',
      );
      expect(controller.settings.themePreference.themeMode, ThemeMode.light);
      controller.dispose();
    });

    test('a persisted theme preference is restored', () async {
      final controller = await buildController(
        initial: <String, Object>{'settings.theme': 'dark'},
      );
      expect(controller.settings.themePreference, AppThemePreference.dark);
      expect(controller.settings.themePreference.themeMode, ThemeMode.dark);
      controller.dispose();
    });

    test('System maps to ThemeMode.system', () async {
      final controller = await buildController(
        initial: <String, Object>{'settings.theme': 'system'},
      );
      expect(controller.settings.themePreference.themeMode, ThemeMode.system);
      controller.dispose();
    });

    test('an unknown stored value falls back to Light', () async {
      final controller = await buildController(
        initial: <String, Object>{'settings.theme': 'neon'},
      );
      expect(controller.settings.themePreference, AppThemePreference.light);
      controller.dispose();
    });

    test('a fresh install starts in Demo mode with notifications disarmed',
        () async {
      final controller = await buildController();
      expect(controller.settings.mode, OperatingMode.demo);
      expect(controller.settings.externalNotificationsArmed, isFalse,
          reason: 'external dispatch must never be armed by default');
      controller.dispose();
    });
  });

  group('layout breakpoints', () {
    test('width maps to the expected layout class', () {
      expect(Breakpoints.of(360), LayoutSize.compact);
      expect(Breakpoints.of(599), LayoutSize.compact);
      expect(Breakpoints.of(600), LayoutSize.medium);
      expect(Breakpoints.of(999), LayoutSize.medium);
      expect(Breakpoints.of(1000), LayoutSize.expanded);
      expect(Breakpoints.of(1360), LayoutSize.large);
      expect(Breakpoints.of(2560), LayoutSize.large);
    });

    test('side navigation appears only on expanded and large', () {
      expect(LayoutSize.compact.hasSideNavigation, isFalse);
      expect(LayoutSize.medium.hasSideNavigation, isFalse);
      expect(LayoutSize.expanded.hasSideNavigation, isTrue);
      expect(LayoutSize.large.hasSideNavigation, isTrue);
    });
  });

  group('app renders', () {
    testWidgets('shows the Overview screen at desktop width', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = await buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(SmartSafetyApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Vehicle node'), findsOneWidget);
      expect(find.text('Wearable'), findsOneWidget);
      expect(find.text('Recent incidents'), findsOneWidget);
    });

    testWidgets('shows the Overview screen at phone width', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = await buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(SmartSafetyApp(controller: controller));
      await tester.pumpAndSettle();

      // Bottom navigation replaces the sidebar on narrow widths.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Vehicle node'), findsOneWidget);
    });

    testWidgets('renders without overflow at several widths', (tester) async {
      final controller = await buildController();
      addTearDown(controller.dispose);

      for (final size in const <Size>[
        Size(360, 720),
        Size(600, 900),
        Size(1000, 800),
        Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(SmartSafetyApp(controller: controller));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'no layout exception at ${size.width.toInt()}px wide',
        );
      }

      tester.view.reset();
    });

    testWidgets('sidebar destinations navigate on desktop', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = await buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(SmartSafetyApp(controller: controller));
      await tester.pumpAndSettle();

      // The Application Bar title reflects the current destination.
      expect(find.widgetWithText(AppBar, 'Overview'), findsOneWidget);

      await tester.tap(find.text('Simulation Lab').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Simulation Lab'), findsOneWidget);
    });

    testWidgets('switches to the dark theme immediately', (tester) async {
      final controller = await buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(SmartSafetyApp(controller: controller));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);

      // The compact theme toggle in the application bar.
      await tester.tap(find.byTooltip('Switch theme'));
      await tester.pumpAndSettle();

      final updated = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(updated.themeMode, ThemeMode.dark);
      expect(controller.settings.themePreference, AppThemePreference.dark);
    });
  });

  group('mode indicator', () {
    testWidgets('demo and live are distinguishable without colour',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Column(
              children: [
                ModeIndicator(mode: OperatingMode.demo),
                ModeIndicator(mode: OperatingMode.hardware),
              ],
            ),
          ),
        ),
      );

      // Distinct words, not just distinct colours.
      expect(find.text('Simulated'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('dark theme indicator still shows both words',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Column(
              children: [
                ModeIndicator(mode: OperatingMode.demo),
                ModeIndicator(mode: OperatingMode.hardware),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Simulated'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });
  });

  group('incident store', () {
    test('adds, searches and clears records', () async {
      final controller = await buildController();
      final store = controller.incidentStore;

      await store.add(
        Incident(
          id: '1',
          category: IncidentCategory.accident,
          origin: IncidentOrigin.demo,
          occurredAt: DateTime(2026, 3, 1, 10),
          status: IncidentStatus.active,
          severity: Severity.critical,
          summary: 'Impact 5.2 g',
          deviceId: 'VN-01',
        ),
      );

      expect(store.count, 1);
      expect(store.open, hasLength(1));
      expect(store.search('impact'), hasLength(1));
      expect(store.search('nonexistent'), isEmpty);

      await store.acknowledge('1');
      expect(store.open, isEmpty);

      await store.clear();
      expect(store.count, 0);

      controller.dispose();
    });

    test('surfaces the most severe open record', () async {
      final controller = await buildController();
      final store = controller.incidentStore;
      final now = DateTime(2026, 3, 1, 10);

      Incident make(String id, Severity severity) => Incident(
            id: id,
            category: IncidentCategory.screening,
            origin: IncidentOrigin.demo,
            occurredAt: now,
            status: IncidentStatus.active,
            severity: severity,
            summary: id,
            deviceId: 'WB-01',
          );

      await store.add(make('a', Severity.caution));
      await store.add(make('b', Severity.critical));
      await store.add(make('c', Severity.info));

      expect(store.mostSevereOpen?.id, 'b');
      controller.dispose();
    });

    test('survives a JSON round-trip', () async {
      final controller = await buildController();

      final original = Incident(
        id: 'x',
        category: IncidentCategory.accident,
        origin: IncidentOrigin.demo,
        occurredAt: DateTime(2026, 3, 1, 10),
        status: IncidentStatus.active,
        severity: Severity.critical,
        summary: 'Impact 5.2 g, rollover',
        deviceId: 'VN-01',
        riskScore: 82,
        band: 'High risk',
        attempts: 2,
        acknowledgements: 1,
        notes: const ['Generated by Demo Mode.'],
      );

      final restored = Incident.fromJson(original.toJson());
      expect(restored?.id, 'x');
      expect(restored?.summary, 'Impact 5.2 g, rollover');
      expect(restored?.attempts, 2);
      expect(restored?.acknowledgements, 1);
      expect(restored?.isSimulated, isTrue);
      expect(restored?.notes, hasLength(1));
      controller.dispose();
    });
  });

  group('about screen', () {
    testWidgets('states the limitations explicitly', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: AboutScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What it does not do'), findsOneWidget);
      expect(
        find.textContaining('cannot prove the cause of an accident'),
        findsOneWidget,
      );
      expect(find.text('Before real-world use'), findsOneWidget);
    });

    testWidgets('renders the illustration without error in both themes',
        (tester) async {
      for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(body: Center(child: SafetyConstellation())),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}