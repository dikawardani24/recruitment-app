import 'package:injectable/injectable.dart';

import '../models.dart';
import '../repositories/chat_repository.dart';

@Injectable()
class AskChat {
  const AskChat(this._repository);

  final ChatRepository _repository;

  Future<ChatResponse> call({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
    String? model,
  }) =>
      _repository.ask(
        question: question,
        jobId: jobId,
        history: history,
        topK: topK,
        model: model,
      );

  Stream<ChatStreamEvent> callStream({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
    String? model,
  }) =>
      _repository.askStream(
        question: question,
        jobId: jobId,
        history: history,
        topK: topK,
        model: model,
      );

  Future<List<ChatModel>> getModels() => _repository.getModels();
}
