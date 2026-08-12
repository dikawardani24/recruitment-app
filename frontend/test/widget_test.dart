import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_ats/di.dart';
import 'package:ai_ats/main.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/router.dart';
import 'package:ai_ats/screens/job_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Disable Chucker's in-app notification so its 1s auto-dismiss timer does
  // not leak into the test and trigger the "Timer still pending" assertion.
  ChuckerFlutter.showNotification = false;
  SharedPreferences.setMockInitialValues({});
  setupDependencies();

  Widget buildApp() {
    final router = AppRouter.create();
    return ProviderScope(
      overrides: [goRouterProvider.overrideWithValue(router)],
      child: AtsApp(router: router),
    );
  }

  testWidgets('App builds and shows the jobs list screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(buildApp());
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.byType(JobListScreen), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('New job'), findsOneWidget);
  });

  testWidgets('shows resize message below the mobile minimum width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text('Window too small'), findsOneWidget);
      expect(find.byType(JobListScreen), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('smallest phone width renders the app, not the resize message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.runAsync(() async {
        await tester.pumpWidget(buildApp());
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.text('Window too small'), findsNothing);
      expect(find.byType(JobListScreen), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile width renders the app, not the resize message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.runAsync(() async {
        await tester.pumpWidget(buildApp());
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.text('Window too small'), findsNothing);
      expect(find.byType(JobListScreen), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
