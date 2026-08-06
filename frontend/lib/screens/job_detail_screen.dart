import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models.dart';
import '../navigation/app_navigator.dart';
import '../providers.dart';
import '../router.dart';
import '../widgets/loading_overlay.dart';

class JobDetailScreen extends HookConsumerWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);
    final loadingMessage = useState<String?>(null);

    final jobAsync = ref.watch(jobProvider(jobId));
    final cvsAsync = ref.watch(cvsProvider(jobId));

    Future<void> refreshCvs() async {
      ref.invalidate(cvsProvider(jobId));
      await ref.read(cvsProvider(jobId).future);
    }

    Future<void> pickCvs() async {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      if (files.isEmpty) return;

      busy.value = true;
      loadingMessage.value = 'Uploading ${files.length} CV(s)…';
      try {
        final uploaded =
            await ref.read(apiClientProvider).uploadCvs(jobId, files);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ${uploaded.length} CV(s)')),
        );
        await refreshCvs();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      } finally {
        if (context.mounted) {
          busy.value = false;
          loadingMessage.value = null;
        }
      }
    }

    Future<void> rank() async {
      busy.value = true;
      loadingMessage.value = 'Ranking candidates…';
      try {
        final response = await ref.read(apiClientProvider).rankJob(jobId);
        if (!context.mounted) return;
        busy.value = false;
        loadingMessage.value = null;
        await refreshCvs();
        ref.read(navigatorProvider).goToRankings(
              RankingsScreenData(
                jobId: jobId,
                jobTitle: jobAsync.value?.title ?? 'Job',
                source: response.source,
              ),
            );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ranking failed: $e')),
        );
      } finally {
        if (context.mounted) {
          busy.value = false;
          loadingMessage.value = null;
        }
      }
    }

    final job = jobAsync.value;
    final cvs = cvsAsync.value ?? [];

    if (jobAsync.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('${jobAsync.error}')),
      );
    }
    if (job == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading job…'),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text(job.title)),
          body: RefreshIndicator(
            onRefresh: refreshCvs,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  job.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (job.description.isEmpty)
                  const Text('No description')
                else
                  _DescriptionView(description: job.description),
                if (job.requirements != null) ...[
                  const SizedBox(height: 16),
                  _RequirementsView(requirements: job.requirements!),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy.value ? null : pickCvs,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Add CVs'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy.value ? null : rank,
                        icon: const Icon(Icons.psychology),
                        label: const Text('Rank candidates'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Candidates (${cvs.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (cvs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No CVs uploaded yet. Tap "Add CVs".'),
                    ),
                  )
                else
                  ...cvs.map((cv) => _CandidateTile(cv: cv)),
              ],
            ),
          ),
        ),
        if (busy.value)
          LoadingOverlay(message: loadingMessage.value ?? 'Loading…'),
      ],
    );
  }
}

class _DescriptionView extends StatelessWidget {
  final String description;

  const _DescriptionView({required this.description});

  String? _jsonToMarkdown(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{')) return null;
    Object? data;
    try {
      data = json.decode(trimmed);
    } catch (_) {
      return null;
    }
    if (data is! Map) return null;

    final buffer = StringBuffer();
    _appendMap(buffer, data, level: 1);
    return buffer.toString().trim();
  }

  String _humanize(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .split(RegExp(r'_|\-'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  void _appendMap(StringBuffer buffer, Map<dynamic, dynamic> map,
      {required int level}) {
    final header = level == 1 ? '### ' : '#### ';
    bool firstSection = level == 1;
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final label = _humanize(key);
      final value = entry.value;
      if (value is Map) {
        buffer.writeln();
        buffer.writeln('$header$label');
        _appendMap(buffer, value, level: level + 1);
        if (firstSection) firstSection = false;
      } else if (value is List) {
        buffer.writeln();
        buffer.writeln('$header$label');
        if (value.isEmpty) {
          buffer.writeln('- none');
        } else {
          for (final item in value) {
            if (item is Map) {
              buffer.writeln();
              _appendMap(buffer, item, level: level + 1);
            } else {
              buffer.writeln('- ${item.toString().trim()}');
            }
          }
        }
        if (level == 1) buffer.writeln();
      } else {
        final str = value.toString().trim();
        if (str.isNotEmpty) {
          buffer.writeln('**$label:** $str');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final md = _jsonToMarkdown(description);
    if (md != null) {
      return MarkdownBody(
        data: md,
        selectable: true,
      );
    }
    return MarkdownBody(data: description);
  }
}

class _RequirementsView extends StatelessWidget {
  final JobRequirements requirements;

  const _RequirementsView({required this.requirements});

  @override
  Widget build(BuildContext context) {
    Widget section(String title, List<String> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items
                  .map((s) => Chip(
                        label: Text(s),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section('Required skills', requirements.requiredSkills),
            section('Preferred skills', requirements.preferredSkills),
            if (requirements.minYears > 0)
              Text('Min ${requirements.minYears.round()} years experience'),
            if (requirements.education != null)
              Text('Education: ${requirements.education}'),
            section('Certifications', requirements.certifications),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final CandidateResult cv;

  const _CandidateTile({required this.cv});

  @override
  Widget build(BuildContext context) {
    final name = cv.candidateName ?? cv.fileName;
    final score = cv.overallScore;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
        ),
        title: Text(name),
        subtitle: Text(
          cv.status == 'failed'
              ? 'Failed: ${cv.error}'
              : score == null
                  ? cv.status
                  : '${(score * 100).round()}% · ${cv.bucket ?? ''}',
        ),
        trailing: score == null
            ? (cv.status == 'failed' ? const Icon(Icons.error_outline) : null)
            : Text(
                '${(score * 100).round()}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
      ),
    );
  }
}
