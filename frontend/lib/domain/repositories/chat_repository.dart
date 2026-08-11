import '../models.dart';

abstract class ChatRepository {
  Future<ChatResponse> ask({
    required String question,
    String? jobId,
    List<ChatMessage> history,
    int topK,
    String? model,
  });

  Stream<ChatStreamEvent> askStream({
    required String question,
    String? jobId,
    List<ChatMessage> history,
    int topK,
    String? model,
  });

  Future<List<ChatModel>> getModels();
}
