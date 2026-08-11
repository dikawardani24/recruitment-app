import 'chat_response.dart';

/// A single streaming copilot event from POST /api/chat/stream.
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatStreamStarted extends ChatStreamEvent {
  const ChatStreamStarted();
}

class ChatStreamStatus extends ChatStreamEvent {
  final String stage;
  final String message;
  const ChatStreamStatus({required this.stage, required this.message});
}

class ChatStreamText extends ChatStreamEvent {
  final String content;
  const ChatStreamText(this.content);
}

class ChatStreamTool extends ChatStreamEvent {
  final String name;
  const ChatStreamTool(this.name);
}

class ChatStreamDone extends ChatStreamEvent {
  final ChatResponse response;
  const ChatStreamDone(this.response);
}

class ChatStreamError extends ChatStreamEvent {
  final String message;
  const ChatStreamError(this.message);
}
