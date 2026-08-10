import '../../domain/models.dart';

/// Chat state: the accumulated conversation plus UI flags.
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  /// Becomes false when the backend reports the copilot is not configured
  /// (no LLM key), so the UI can surface a setup hint.
  final bool configured;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.configured = true,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? configured,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      configured: configured ?? this.configured,
    );
  }
}
