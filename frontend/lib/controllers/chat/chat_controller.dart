import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import '../../domain/models.dart';
import '../../domain/usecases/ask_chat.dart';
import 'chat_state.dart';

/// Owns the recruiter-copilot conversation. Each turn sends the accumulated
/// history so follow-up questions work, streams the answer into a single
/// assistant bubble, and appends the grounded answer with its cited sources.
class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final history = state.messages;
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: ChatRole.user, content: trimmed),
      ],
      isLoading: true,
      streamingText: '',
      usingTools: false,
    );

    try {
      await for (final event in getIt<AskChat>().callStream(
        question: trimmed,
        history: history,
      )) {
        switch (event) {
          case ChatStreamText(:final content):
            state = state.copyWith(
              streamingText: '${state.streamingText}$content',
            );
          case ChatStreamTool():
            state = state.copyWith(usingTools: true);
          case ChatStreamDone(:final response):
            state = ChatState(
              messages: [
                ...state.messages,
                ChatMessage(
                  role: ChatRole.assistant,
                  content: response.answer,
                  sources: response.sources,
                ),
              ],
              configured: response.configured,
            );
          case ChatStreamError(:final message):
            state = ChatState(
              messages: [
                ...state.messages,
                ChatMessage(
                  role: ChatRole.assistant,
                  content: 'Sorry, something went wrong: $message',
                ),
              ],
              configured: state.configured,
            );
        }
      }
    } catch (e) {
      state = ChatState(
        messages: [
          ...state.messages,
          ChatMessage(
            role: ChatRole.assistant,
            content: 'Sorry, something went wrong: $e',
          ),
        ],
        configured: state.configured,
      );
    }
  }

  void clear() => state = const ChatState();
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
