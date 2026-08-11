import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/controllers/chat/chat_controller.dart';
import 'package:ai_ats/di.dart';
import 'package:ai_ats/domain/models.dart';
import 'package:ai_ats/domain/repositories/chat_repository.dart';
import 'package:ai_ats/domain/usecases/ask_chat.dart';

class _FakeRepo implements ChatRepository {
  _FakeRepo() : controller = StreamController.broadcast();

  final StreamController<ChatStreamEvent> controller;

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
  late _FakeRepo repo;
  late ProviderContainer container;

  setUp(() {
    getIt.reset();
    repo = _FakeRepo();
    getIt.registerSingleton<AskChat>(AskChat(repo));
    container = ProviderContainer();
  });

  tearDown(() async {
    await repo.controller.close();
    container.dispose();
    getIt.reset();
  });

  test('status then text then done: single assistant message', () async {
    final controller = container.read(chatControllerProvider.notifier);
    final send = controller.send('who is the best candidate?');
    await pumpEventQueue();

    repo.controller.add(const ChatStreamStarted());
    await pumpEventQueue();
    expect(container.read(chatControllerProvider).isLoading, isTrue);

    repo.controller.add(const ChatStreamStatus(
      stage: 'routing',
      message: 'Understanding your request...',
    ));
    await pumpEventQueue();
    expect(
      container.read(chatControllerProvider).statusMessage,
      'Understanding your request...',
    );

    repo.controller.add(const ChatStreamStatus(
      stage: 'retrieving',
      message: 'Finding the relevant information...',
    ));
    await pumpEventQueue();
    expect(
      container.read(chatControllerProvider).statusMessage,
      'Finding the relevant information...',
    );
    expect(container.read(chatControllerProvider).messages, hasLength(1));

    repo.controller.add(const ChatStreamText('Jane Doe '));
    await pumpEventQueue();
    expect(container.read(chatControllerProvider).streamingText, 'Jane Doe ');
    expect(container.read(chatControllerProvider).statusMessage, isNull);

    repo.controller.add(const ChatStreamText('matches [1].'));
    await pumpEventQueue();
    expect(
      container.read(chatControllerProvider).streamingText,
      'Jane Doe matches [1].',
    );

    repo.controller.add(ChatStreamDone(
      ChatResponse(
        configured: true,
        answer: 'Jane Doe matches [1].',
        sources: [
          ChatSource(
            entityType: 'candidate',
            entityId: 'cv-1',
            jobId: 'job-1',
            name: 'Jane Doe',
            section: 'summary',
            score: 0.9,
          ),
        ],
        retrievalEnabled: true,
        retrievalCount: 1,
      ),
    ));
    await repo.controller.close();
    await send;

    final state = container.read(chatControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.statusMessage, isNull);
    expect(state.streamingText, isEmpty);
    expect(state.messages, hasLength(2));
    expect(state.messages[0].isUser, isTrue);
    expect(state.messages[1].isUser, isFalse);
    expect(state.messages[1].content, 'Jane Doe matches [1].');
    expect(state.messages[1].sources, hasLength(1));
  });

  test('error event finalizes with friendly message and clears status',
      () async {
    final controller = container.read(chatControllerProvider.notifier);
    final send = controller.send('what is flutter?');
    await pumpEventQueue();

    repo.controller.add(const ChatStreamStatus(
      stage: 'reasoning',
      message: 'Preparing your answer...',
    ));
    await pumpEventQueue();

    repo.controller.add(const ChatStreamError('chat_call_failed'));
    await repo.controller.close();
    await send;

    final state = container.read(chatControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.statusMessage, isNull);
    expect(state.messages, hasLength(2));
    expect(state.messages[1].content, 'Our system is facing a technical issue. '
        'Please contact the system administrator or try again later.');
  });
}