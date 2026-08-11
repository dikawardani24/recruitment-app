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
  ChatState build() {
    loadModels();
    return const ChatState();
  }

  /// Fetches the available chat models from the backend and defaults the
  /// selection to the first one (the default provider's model).
  Future<void> loadModels() async {
    try {
      final models = await getIt<AskChat>().getModels();
      if (models.isEmpty) return;
      state = state.copyWith(
        models: models,
        selectedModel: state.selectedModel ?? models.first.id,
      );
    } catch (_) {
      // Leave models empty; the picker stays hidden and chat falls back to
      // the backend's default model.
    }
  }

  void selectModel(String id) {
    if (state.models.any((m) => m.id == id)) {
      state = state.copyWith(selectedModel: id);
    }
  }

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
        model: state.selectedModel,
      )) {
        switch (event) {
          case ChatStreamStarted():
            break;
          case ChatStreamStatus(:final message):
            state = state.copyWith(statusMessage: message);
          case ChatStreamText(:final content):
            state = state.copyWith(
              streamingText: '${state.streamingText}$content',
              statusMessage: null,
            );
          case ChatStreamTool():
            state = state.copyWith(
              usingTools: true,
              statusMessage: 'Consulting workspace data…',
            );
          case ChatStreamDone(:final response):
            state = state.copyWith(
              messages: [
                ...state.messages,
                ChatMessage(
                  role: ChatRole.assistant,
                  content: response.answer,
                  sources: response.sources,
                  cards: response.cards,
                ),
              ],
              configured: response.configured,
              isLoading: false,
              streamingText: '',
              statusMessage: null,
              usingTools: false,
            );
          case ChatStreamError(:final message):
            state = state.copyWith(
              messages: [
                ...state.messages,
                ChatMessage(
                  role: ChatRole.assistant,
                  content: _friendlyError(message),
                ),
              ],
              configured: state.configured,
              isLoading: false,
              streamingText: '',
              statusMessage: null,
              usingTools: false,
            );
        }
      }
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            role: ChatRole.assistant,
            content: _friendlyError('$e'),
          ),
        ],
        configured: state.configured,
        isLoading: false,
        streamingText: '',
        statusMessage: null,
        usingTools: false,
      );
    }
  }

  void clear() {
    state = ChatState(
      models: state.models,
      selectedModel: state.selectedModel,
    );
  }
}

String _friendlyError(String raw) {
  final lower = raw.toLowerCase();
  final isRateLimit = lower.contains('ratelimit') ||
      lower.contains('rate_limit') ||
      lower.contains('429') ||
      lower.contains('quota') ||
      lower.contains('too many requests') ||
      lower.contains('resourceexhausted');
  return isRateLimit
      ? 'You have reached the limit, please try again later.'
      : 'Our system is facing a technical issue. '
          'Please contact the system administrator or try again later.';
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
