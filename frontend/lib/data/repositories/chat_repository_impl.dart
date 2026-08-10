import 'package:injectable/injectable.dart';

import '../../domain/models.dart';
import '../../domain/repositories/chat_repository.dart';
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
  }) async {
    final dto = await _dataSource.ask(
      question: question,
      jobId: jobId,
      history: history,
      topK: topK,
    );
    return ChatResponse(
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
}
