import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:ai_ats/controllers/api_key_controller.dart';
import 'package:ai_ats/controllers/chat/chat_controller.dart';
import 'package:ai_ats/controllers/chat/chat_state.dart';
import 'package:ai_ats/domain/models.dart';
import 'package:ai_ats/screens/chat_screen.dart';

class _FixedChatController extends ChatController {
  _FixedChatController({this.selected = 'default'});

  final String selected;

  @override
  ChatState build() => ChatState(
        configured: true,
        models: const [
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
        ],
        selectedModel: selected,
      );
}

class _FixedApiKeyController extends ApiKeyController {
  _FixedApiKeyController(this.values);

  final Map<String, String?> values;

  @override
  Map<String, String?> build() => values;
}

void main() {
  Future<void> pumpChat(
    WidgetTester tester, {
    Map<String, String?> apiKeys = const {},
    String selected = 'default',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiKeyProvider.overrideWith(() => _FixedApiKeyController(apiKeys)),
          chatControllerProvider.overrideWith(
            () => _FixedChatController(selected: selected),
          ),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('banner shown when the user set their own key for the model', (
    tester,
  ) async {
    await pumpChat(tester, apiKeys: {'default': 'AIzaSy-very-long-key'});

    expect(find.textContaining('Using your saved'), findsOneWidget);
    expect(find.textContaining('Gemini (Default)'), findsOneWidget);
  });

  testWidgets('no banner when the user set no key', (tester) async {
    await pumpChat(tester);

    expect(find.textContaining('Using your saved'), findsNothing);
  });

  testWidgets('no banner when the key is set for the other provider', (
    tester,
  ) async {
    await pumpChat(tester, apiKeys: {'openrouter': 'sk-or-very-long-key'});

    expect(find.textContaining('Using your saved'), findsNothing);
  });

  testWidgets('banner follows the selected model provider', (tester) async {
    await pumpChat(
      tester,
      apiKeys: {'openrouter': 'sk-or-very-long-key'},
      selected: 'openrouter:qwen/qwen-2.5-72b-instruct',
    );

    expect(
      find.textContaining('Using your saved OpenRouter API key'),
      findsOneWidget,
    );
  });
}
