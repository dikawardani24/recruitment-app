import '../../domain/models.dart';

/// Chat state: the accumulated conversation plus UI flags.
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  /// Becomes false when the backend reports the copilot is not configured
  /// (no LLM key), so the UI can surface a setup hint.
  final bool configured;

  /// In-progress assistant text while the answer streams. Only one bubble is
  /// rendered for it; it becomes a finalized [ChatMessage] on [ChatStreamDone].
  final String streamingText;

  /// Latest progress message from the backend (e.g. "Searching relevant
  /// candidates..."). Shown while no answer text has arrived yet; cleared as
  /// soon as tokens start streaming.
  final String? statusMessage;

  /// Whether the copilot is currently querying workspace records (tools).
  final bool usingTools;

  /// Chat models available from the backend (default provider + OpenRouter).
  final List<ChatModel> models;

  /// Currently selected chat model id, or null when none loaded yet.
  final String? selectedModel;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.configured = true,
    this.streamingText = '',
    this.statusMessage,
    this.usingTools = false,
    this.models = const [],
    this.selectedModel,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? configured,
    String? streamingText,
    Object? statusMessage = _unset,
    bool? usingTools,
    List<ChatModel>? models,
    Object? selectedModel = _unset,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      configured: configured ?? this.configured,
      streamingText: streamingText ?? this.streamingText,
      statusMessage: identical(statusMessage, _unset)
          ? this.statusMessage
          : statusMessage as String?,
      usingTools: usingTools ?? this.usingTools,
      models: models ?? this.models,
      selectedModel: identical(selectedModel, _unset)
          ? this.selectedModel
          : selectedModel as String?,
    );
  }
}

const _unset = Object();
