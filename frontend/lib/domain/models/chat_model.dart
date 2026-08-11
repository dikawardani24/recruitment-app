/// A selectable recruiter-copilot chat model exposed by the backend
/// (GET /api/chat/models). ``id`` is sent back with chat requests.
class ChatModel {
  final String id;
  final String label;
  final String provider;
  final String model;

  const ChatModel({
    required this.id,
    required this.label,
    required this.provider,
    required this.model,
  });
}
