import 'chat_source.dart';

/// One turn of the recruiter-copilot chat.
class ChatResponse {
  final bool configured;
  final String answer;
  final List<ChatSource> sources;
  final bool retrievalEnabled;
  final int retrievalCount;

  const ChatResponse({
    required this.configured,
    required this.answer,
    required this.sources,
    required this.retrievalEnabled,
    required this.retrievalCount,
  });
}
