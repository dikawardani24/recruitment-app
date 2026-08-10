import '../models.dart';

abstract class ChatRepository {
  Future<ChatResponse> ask({
    required String question,
    String? jobId,
    List<ChatMessage> history,
    int topK,
  });

  Stream<ChatStreamEvent> askStream({
    required String question,
    String? jobId,
    List<ChatMessage> history,
    int topK,
  });
}
