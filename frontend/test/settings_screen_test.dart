import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_ats/di.dart';
import 'package:ai_ats/main.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/router.dart';
import 'package:ai_ats/screens/job_list_screen.dart';
import 'package:ai_ats/screens/settings_screen.dart';
import 'package:ai_ats/theme/theme_controller.dart';

/// In-memory jobs notifier so the tests never hit the network (which would
/// also trigger Chucker's request logging and pending notification timers).
class _FakeJobListNotifier extends JobListNotifier {
  @override
  Future<JobListState> build() async {
    return JobListState(jobs: const [], page: 1, hasMore: false);
  }
}

void main() {
  setupDependencies();

  Future<SharedPreferences> mockPrefs(
    WidgetTester tester, [
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    late SharedPreferences prefs;
    await tester.runAsync(() async {
      prefs = await SharedPreferences.getInstance();
    });
    return prefs;
  }

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    SharedPreferences? prefs,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final effective = prefs ?? await mockPrefs(tester);
    final router = AppRouter.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          sharedPreferencesProvider.overrideWithValue(effective),
          jobsProvider.overrideWith(() => _FakeJobListNotifier()),
        ],
        child: AtsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Brightness brightnessOf(WidgetTester tester, Type screen) {
    return Theme.of(tester.element(find.byType(screen))).brightness;
  }

  testWidgets('app bar settings action opens the settings page', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('defaults to the system theme (light in the test harness)', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(brightnessOf(tester, JobListScreen), Brightness.light);
  });

  testWidgets('selecting a theme updates the app immediately', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(brightnessOf(tester, SettingsScreen), Brightness.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(brightnessOf(tester, SettingsScreen), Brightness.light);
  });

  testWidgets('persists the selected theme', (tester) async {
    final prefs = await mockPrefs(tester);
    await pumpApp(tester, prefs: prefs);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('restores a persisted dark theme on startup', (tester) async {
    final prefs = await mockPrefs(tester, {'theme_mode': 'dark'});
    await pumpApp(tester, prefs: prefs);

    expect(brightnessOf(tester, JobListScreen), Brightness.dark);
  });

  testWidgets('system mode follows the OS brightness', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    expect(brightnessOf(tester, JobListScreen), Brightness.dark);
  });
}
