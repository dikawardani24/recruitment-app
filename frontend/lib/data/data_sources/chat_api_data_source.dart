import 'dart:async';
import 'dart:convert';

import 'package:injectable/injectable.dart';

import '../api/api_client.dart';
import '../api/api_paths.dart';
import '../api/chat_stream_events.dart';
import '../api/mappers.dart';
import '../api/response_models.dart';
import '../../domain/models.dart';

@Injectable()
class ChatApiDataSource {
  ChatApiDataSource(this._client);

  final ApiClient _client;

  Future<ChatResponseDto> ask({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
    String? model,
  }) {
    final data = <String, dynamic>{
      'question': question,
      'history': [
        for (final turn in history)
          {'role': turn.roleName, 'content': turn.content},
      ],
      'top_k': topK,
      'job_id': ?jobId,
      'model': ?model,
    };
    return _client.post(
      ApiPaths.chat,
      data: data,
      parse: (resp) => ChatResponseMapper.fromJson(resp as Map<String, dynamic>),
    );
  }

  /// Consumes the SSE stream from POST /api/chat/stream and yields parsed
  /// events (text deltas, tool progress, terminal done/error).
  Stream<ChatStreamEventDto> askStream({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
    String? model,
  }) {
    final data = <String, dynamic>{
      'question': question,
      'history': [
        for (final turn in history)
          {'role': turn.roleName, 'content': turn.content},
      ],
      'top_k': topK,
      'job_id': ?jobId,
      'model': ?model,
    };

    final controller = StreamController<ChatStreamEventDto>();
    final buffer = StringBuffer();

    void processBuffer() {
      var text = buffer.toString();
      while (true) {
        final end = text.indexOf('\n\n');
        if (end < 0) break;
        final frame = text.substring(0, end);
        text = text.substring(end + 2);
        final event = _parseFrame(frame);
        if (event != null && !controller.isClosed) {
          controller.add(event);
        }
      }
      buffer
        ..clear()
        ..write(text);
    }

    final sub = _client
        .postStream(ApiPaths.chatStream, data: data)
        .transform(utf8.decoder)
        .listen(
          (chunk) {
            buffer.write(chunk);
            processBuffer();
          },
          onError: (Object error, StackTrace stack) {
            if (!controller.isClosed) {
              controller.addError(error, stack);
              controller.close();
            }
          },
          onDone: () {
            if (!controller.isClosed) controller.close();
          },
        );

    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  Future<List<ChatModelDto>> getModels() {
    return _client.get(
      ApiPaths.chatModels,
      parse: (resp) => ChatModelsMapper.fromJson(resp as Map<String, dynamic>),
    );
  }

  ChatStreamEventDto? _parseFrame(String frame) {
    String? payload;
    for (final line in const LineSplitter().convert(frame)) {
      if (line.startsWith('data:')) {
        payload = line.substring(5).trim();
        break;
      }
    }
    if (payload == null || payload.isEmpty) return null;

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    switch (json['type']) {
      case 'started':
        return const ChatStreamStartedDto();
      case 'status':
        return ChatStreamStatusDto(
          stage: json['stage'] as String? ?? '',
          message: json['message'] as String? ?? '',
        );
      case 'text':
        final content = json['content'] as String? ?? '';
        return content.isEmpty ? null : ChatStreamTextDto(content);
      case 'tool':
        return ChatStreamToolDto(json['name'] as String? ?? '');
      case 'done':
        return ChatStreamDoneDto(ChatResponseMapper.fromJson(json));
      case 'error':
        return ChatStreamErrorDto(json['message'] as String? ?? 'chat_error');
    }
    return null;
  }
}
