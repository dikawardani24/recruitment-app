import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_ats/controllers/api_key_controller.dart';
import 'package:ai_ats/controllers/chat/chat_controller.dart';
import 'package:ai_ats/controllers/chat/chat_state.dart';
import 'package:ai_ats/di.dart';
import 'package:ai_ats/domain/models.dart';
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

class _FixedChatController extends ChatController {
  _FixedChatController(this.models);

  final List<ChatModel> models;

  @override
  ChatState build() => ChatState(
        models: models,
        selectedModel: models.isNotEmpty ? models.first.id : null,
      );
}

class _FixedApiKeyController extends ApiKeyController {
  _FixedApiKeyController(this.keys);

  final Map<String, String?> keys;

  @override
  Map<String, String?> build() => keys;
}

const _serverModels = [
  ChatModel(
    id: 'default',
    label: 'gemini-flash-latest',
    provider: 'default',
    model: 'gemini-flash-latest',
  ),
  ChatModel(
    id: 'openrouter:qwen/qwen-2.5-72b-instruct',
    label: 'Qwen via OpenRouter (qwen/qwen-2.5-72b-instruct)',
    provider: 'openrouter',
    model: 'qwen/qwen-2.5-72b-instruct',
  ),
];

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
    List<Override> overrides = const [],
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
          ...overrides,
        ],
        child: AtsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
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

  testWidgets('shows app default models when no user API key is set', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: [
        chatControllerProvider.overrideWith(() => _FixedChatController(_serverModels)),
        apiKeyProvider.overrideWith(() => _FixedApiKeyController(const {})),
      ],
    );
    await openSettings(tester);

    expect(find.text('Gemini (Default)'), findsOneWidget);
    expect(find.text('OpenRouter'), findsOneWidget);
    expect(find.textContaining('App default'), findsNWidgets(2));
    expect(find.text('Not configured'), findsNothing);
  });

  testWidgets('shows user-set keys and not configured for the rest', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: [
        chatControllerProvider.overrideWith(() => _FixedChatController(const [])),
        apiKeyProvider.overrideWith(
          () => _FixedApiKeyController({'default': 'AIzaSy-very-long-key'}),
        ),
      ],
    );
    await openSettings(tester);

    expect(find.textContaining('Using your saved key'), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
  });

  testWidgets('shows not configured for both when nothing is set', (tester) async {
    await pumpApp(
      tester,
      overrides: [
        chatControllerProvider.overrideWith(() => _FixedChatController(const [])),
        apiKeyProvider.overrideWith(() => _FixedApiKeyController(const {})),
      ],
    );
    await openSettings(tester);

    expect(find.text('Not configured'), findsNWidgets(2));
  });
}
