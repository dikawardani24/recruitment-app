import 'response_models.dart';

/// SSE frames emitted by POST /api/chat/stream, before mapping to domain.
sealed class ChatStreamEventDto {
  const ChatStreamEventDto();
}

class ChatStreamTextDto extends ChatStreamEventDto {
  final String content;
  const ChatStreamTextDto(this.content);
}

class ChatStreamToolDto extends ChatStreamEventDto {
  final String name;
  const ChatStreamToolDto(this.name);
}

class ChatStreamDoneDto extends ChatStreamEventDto {
  final ChatResponseDto response;
  const ChatStreamDoneDto(this.response);
}

class ChatStreamErrorDto extends ChatStreamEventDto {
  final String message;
  const ChatStreamErrorDto(this.message);
}
