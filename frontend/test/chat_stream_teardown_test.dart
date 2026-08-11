import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:ai_ats/di.dart';
import 'package:ai_ats/domain/models.dart';
import 'package:ai_ats/domain/repositories/chat_repository.dart';
import 'package:ai_ats/domain/usecases/ask_chat.dart';
import 'package:ai_ats/screens/chat_screen.dart';

class _FakeRepo implements ChatRepository {
  _FakeRepo() {
    controller = StreamController<ChatStreamEvent>.broadcast(onListen: () {
      for (final event in _events) {
        controller.add(event);
      }
    });
  }

  static const _events = <ChatStreamEvent>[
    ChatStreamTool('retrieve'),
    ChatStreamText('Here are the requirements for a '),
    ChatStreamText('**junior Android developer**:\n'),
    ChatStreamText('- Kotlin basics\n'),
    ChatStreamText('- Android SDK\n'),
    ChatStreamText('- Jetpack Compose'),
  ];

  late final StreamController<ChatStreamEvent> controller;

  @override
  Future<ChatResponse> ask({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
  }) async {
    return const ChatResponse(
      configured: true,
      answer: '',
      sources: [],
      retrievalEnabled: true,
      retrievalCount: 0,
    );
  }

  @override
  Stream<ChatStreamEvent> askStream({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
  }) {
    return controller.stream;
  }
}

void main() {
  setUp(() {
    getIt.reset();
  });

  tearDown(() {
    getIt.reset();
  });

  testWidgets('streaming markdown teardown does not throw', (tester) async {
    final repo = _FakeRepo();
    getIt.registerSingleton<AskChat>(AskChat(repo));

    await tester.pumpWidget(
      ProviderScope(
        child: const MaterialApp(home: ChatScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'requirements for junior android');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // Let a few tokens land.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MarkdownBody), findsWidgets);

    // Tear the chat screen down mid-stream.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    // Repaint any pending frames; a deactivated-ancestor lookup throws here.
    await tester.pump();
    repo.controller.close();
  });
}
