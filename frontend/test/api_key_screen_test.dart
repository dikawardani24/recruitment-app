import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_ats/controllers/api_key_controller.dart';
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

    // The add-key form is shown with the first provider pre-selected.
    expect(find.text('Add API Key'), findsOneWidget);
    expect(find.text('Save API Key'), findsOneWidget);
    expect(find.text('Gemini (Default) API Key'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    // Both providers are selectable from the dropdown.
    await tester.tap(find.byType(DropdownButtonFormField<ApiKeyProvider>));
    await tester.pumpAndSettle();
    expect(find.text('Gemini (Default)'), findsWidgets);
    expect(find.text('OpenRouter'), findsWidgets);
  });

  testWidgets('with one key set the other provider still offers an add input', (
    tester,
  ) async {
    final prefs = await mockPrefs(tester, {
      'api_key_default': 'AIzaSy0123456789abcdefghijklmnopqrstuvwxyz123',
    });
    await pumpScreen(tester, prefs: prefs);

    // The saved key is listed with a masked preview and a delete action.
    expect(find.textContaining('••••'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // The remaining provider is offered in the add form.
    expect(find.text('OpenRouter API Key'), findsOneWidget);
    expect(find.text('Save API Key'), findsOneWidget);
  });

  testWidgets('no add input when both keys are already set', (tester) async {
    final prefs = await mockPrefs(tester, {
      'api_key_default': 'AIzaSy0123456789abcdefghijklmnopqrstuvwxyz123',
      'api_key_openrouter': 'sk-or-v1-0123456789abcdef0123456789abcdef',
    });
    await pumpScreen(tester, prefs: prefs);

    expect(find.text('Saved API Keys'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    expect(find.text('Add API Key'), findsNothing);
    expect(find.text('Save API Key'), findsNothing);
  });

  testWidgets('delete removes the saved key and reveals the add input', (
    tester,
  ) async {
    final prefs = await mockPrefs(tester, {
      'api_key_default': 'AIzaSy0123456789abcdefghijklmnopqrstuvwxyz123',
    });
    await pumpScreen(tester, prefs: prefs);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(prefs.getString('api_key_default'), isNull);
    expect(find.text('Add API Key'), findsOneWidget);
    expect(find.text('Save API Key'), findsOneWidget);
  });
}
