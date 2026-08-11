import 'chat_card.dart';
import 'chat_source.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String content;
  final List<ChatSource> sources;
  final List<ChatCardGroup> cards;

  const ChatMessage({
    required this.role,
    required this.content,
    this.sources = const [],
    this.cards = const [],
  });

  bool get isUser => role == ChatRole.user;

  String get roleName => isUser ? 'user' : 'assistant';
}
