import '../models.dart';

abstract class ChatRepository {
  Future<ChatResponse> ask({
    required String question,
    String? jobId,
    List<ChatMessage> history,
    int topK,
    String? model,
    String? apiKey,
  });

  Stream<ChatStreamEvent> askStream({
    required String question,
    String? jobId,
    List<ChatMessage> history,
    int topK,
    String? model,
    String? apiKey,
  });

  Future<List<ChatModel>> getModels();
}
