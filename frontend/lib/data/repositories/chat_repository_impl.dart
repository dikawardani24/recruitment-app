import 'package:injectable/injectable.dart';

import '../../domain/models.dart';
import '../../domain/repositories/chat_repository.dart';
import '../api/chat_stream_events.dart';
import '../api/response_models.dart';
import '../data_sources/chat_api_data_source.dart';

@Injectable(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._dataSource);

  final ChatApiDataSource _dataSource;

  @override
  Future<ChatResponse> ask({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
    String? model,
  }) async {
    final dto = await _dataSource.ask(
      question: question,
      jobId: jobId,
      history: history,
      topK: topK,
      model: model,
    );
    return _toResponse(dto);
  }

  @override
  Stream<ChatStreamEvent> askStream({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
    String? model,
  }) async* {
    await for (final event in _dataSource.askStream(
      question: question,
      jobId: jobId,
      history: history,
      topK: topK,
      model: model,
    )) {
      yield switch (event) {
        ChatStreamStartedDto() => const ChatStreamStarted(),
        ChatStreamStatusDto(:final stage, :final message) =>
          ChatStreamStatus(stage: stage, message: message),
        ChatStreamTextDto(:final content) => ChatStreamText(content),
        ChatStreamToolDto(:final name) => ChatStreamTool(name),
        ChatStreamDoneDto(:final response) => ChatStreamDone(_toResponse(response)),
        ChatStreamErrorDto(:final message) => ChatStreamError(message),
      };
    }
  }

  @override
  Future<List<ChatModel>> getModels() async {
    final models = await _dataSource.getModels();
    return models
        .map(
          (m) => ChatModel(
            id: m.id,
            label: m.label,
            provider: m.provider,
            model: m.model,
          ),
        )
        .toList();
  }

  ChatResponse _toResponse(ChatResponseDto dto) => ChatResponse(
        configured: dto.configured,
        answer: dto.answer,
        sources: dto.sources
            .map(
              (s) => ChatSource(
                entityType: s.entityType,
                entityId: s.entityId,
                jobId: s.jobId,
                name: s.name,
                section: s.section,
                score: s.score,
              ),
            )
            .toList(),
        retrievalEnabled: dto.retrievalEnabled,
        retrievalCount: dto.retrievalCount,
      );
}
