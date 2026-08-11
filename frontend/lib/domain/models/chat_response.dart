import 'chat_card.dart';
import 'chat_source.dart';

/// One turn of the recruiter-copilot chat.
class ChatResponse {
  final bool configured;
  final String answer;
  final List<ChatSource> sources;
  final List<ChatCardGroup> cards;
  final bool retrievalEnabled;
  final int retrievalCount;

  const ChatResponse({
    required this.configured,
    required this.answer,
    required this.sources,
    this.cards = const [],
    required this.retrievalEnabled,
    required this.retrievalCount,
  });
}
