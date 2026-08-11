import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/chat/chat_controller.dart';
import '../domain/models.dart';

class ChatScreen extends HookConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final inputController = useTextEditingController();
    final scrollController = useScrollController();

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.jumpTo(scrollController.position.maxScrollExtent);
        }
      });
      return null;
    }, [chatState.messages.length, chatState.streamingText]);

    void send() {
      final text = inputController.text;
      inputController.clear();
      controller.send(text);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recruiter Copilot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: chatState.messages.isEmpty ? null : controller.clear,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!chatState.configured) const _NotConfiguredBanner(),
          Expanded(
            child: chatState.messages.isEmpty && !chatState.isLoading
                ? const _EmptyChat()
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: chatState.messages.length +
                        (chatState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chatState.messages.length) {
                        return _StreamingBubble(
                          streamingText: chatState.streamingText,
                          statusMessage: chatState.statusMessage,
                          usingTools: chatState.usingTools,
                        );
                      }
                      final message = chatState.messages[index];
                      return _MessageBubble(message: message);
                    },
                  ),
          ),
          _Composer(controller: inputController, onSend: send),
        ],
      ),
    );
  }
}

class _NotConfiguredBanner extends StatelessWidget {
  const _NotConfiguredBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The copilot needs an LLM key (ATS_LLM__API_KEY). '
              'Enable semantic search (ATS_RAG__ENABLED=true) for grounded answers.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.support_agent,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Ask anything about your candidates', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'e.g. "Who is the strongest Flutter candidate?" or '
              '"What does the backend job require?"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              SelectableText(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              )
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _CopyButton(
                    text: message.content,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet.fromTheme(theme),
              ),
            ],
            if (!isUser && message.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final group in _groupSources(message.sources))
                    _SourceChip(group: group),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Copy response',
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: const Text('Response copied'),
                  duration: const Duration(seconds: 2),
                ),
              );
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.copy_rounded, size: 16, color: color),
        ),
      ),
    );
  }
}

class _SourceGroup {
  _SourceGroup({required this.label, required this.name, required this.sections});

  final String label;
  final String name;
  final List<({String section, double score})> sections;
}

List<_SourceGroup> _groupSources(List<ChatSource> sources) {
  final byEntity = <String, _SourceGroup>{};
  for (final source in sources) {
    final key = '${source.entityType}:${source.entityId}';
    final group = byEntity.putIfAbsent(
      key,
      () => _SourceGroup(
        label: source.label,
        name: source.name,
        sections: [],
      ),
    );
    group.sections.add((section: source.section, score: source.score));
  }
  final groups = byEntity.values.toList();
  for (final group in groups) {
    group.sections.sort((a, b) => b.score.compareTo(a.score));
  }
  groups.sort((a, b) => b.sections.first.score.compareTo(a.sections.first.score));
  return groups;
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.group});

  final _SourceGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tooltip = group.sections
        .map((s) => '${s.section} · match ${(s.score * 100).round()}%')
        .join('\n');
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${group.label} · ${group.name}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({
    required this.streamingText,
    required this.statusMessage,
    required this.usingTools,
  });

  final String streamingText;
  final String? statusMessage;
  final bool usingTools;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = streamingText.isNotEmpty;
    final message = statusMessage ??
        (usingTools ? 'Consulting workspace data…' : 'Thinking…');
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: hasText
            ? MarkdownBody(
                data: streamingText,
                styleSheet: MarkdownStyleSheet.fromTheme(theme),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask about a job or candidate…',
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send),
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }
}
