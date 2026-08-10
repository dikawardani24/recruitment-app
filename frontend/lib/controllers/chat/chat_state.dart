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

  /// Whether the copilot is currently querying workspace records (tools).
  final bool usingTools;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.configured = true,
    this.streamingText = '',
    this.usingTools = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? configured,
    String? streamingText,
    bool? usingTools,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      configured: configured ?? this.configured,
      streamingText: streamingText ?? this.streamingText,
      usingTools: usingTools ?? this.usingTools,
    );
  }
}
