import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_ats/di.dart';
import 'package:ai_ats/screens/api_key_screen.dart';
import 'package:ai_ats/theme/theme_controller.dart';

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

  Future<void> pumpScreen(
    WidgetTester tester, {
    SharedPreferences? prefs,
  }) async {
    final effective = prefs ?? await mockPrefs(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(effective),
        ],
        child: const MaterialApp(home: ApiKeyScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an add input for both providers when none is set', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Save Gemini (Default) API Key'), findsOneWidget);
    expect(find.text('Save OpenRouter API Key'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('with one key set the other provider still offers an add input', (
    tester,
  ) async {
    final prefs = await mockPrefs(tester, {
      'api_key_default': 'AIzaSy0123456789abcdefghijklmnopqrstuvwxyz123',
    });
    await pumpScreen(tester, prefs: prefs);

    expect(find.textContaining('••••'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Save OpenRouter API Key'), findsOneWidget);
    expect(find.text('Save Gemini (Default) API Key'), findsNothing);
  });

  testWidgets('no add input when both keys are already set', (tester) async {
    final prefs = await mockPrefs(tester, {
      'api_key_default': 'AIzaSy0123456789abcdefghijklmnopqrstuvwxyz123',
      'api_key_openrouter': 'sk-or-v1-0123456789abcdef0123456789abcdef',
    });
    await pumpScreen(tester, prefs: prefs);

    expect(find.text('Delete'), findsNWidgets(2));
    expect(find.textContaining('Save '), findsNothing);
  });

  testWidgets('delete removes the saved key and reveals the add input', (
    tester,
  ) async {
    final prefs = await mockPrefs(tester, {
      'api_key_default': 'AIzaSy0123456789abcdefghijklmnopqrstuvwxyz123',
    });
    await pumpScreen(tester, prefs: prefs);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(prefs.getString('api_key_default'), isNull);
    expect(find.text('Save Gemini (Default) API Key'), findsOneWidget);
  });
}
