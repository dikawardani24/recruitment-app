import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/job_detail_controller.dart';
import '../models.dart';
import '../navigation/app_navigator.dart';
import '../providers.dart';
import '../widgets/bucket_donut.dart';
import '../widgets/gradient_header.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/score_color.dart';
import 'action_result_screen.dart';
import 'delete_confirm_screen.dart';

class JobDetailScreen extends HookConsumerWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobProvider(jobId));
    final cvsAsync = ref.watch(cvsProvider(jobId));
    final rankingsAsync = ref.watch(rankingsProvider(jobId));

    final detailState = ref.watch(jobDetailControllerProvider);
    final detailController = ref.read(jobDetailControllerProvider.notifier);

    Future<void> pickCvs() async {
      final messenger = ScaffoldMessenger.of(context);
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

      try {
        final uploaded = await detailController.uploadCvs(jobId, files);
        messenger.showSnackBar(
          SnackBar(content: Text('Uploaded $uploaded CV(s)')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }

    Future<void> rank() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await detailController.rank(jobId);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Ranking failed: $e')),
        );
      }
    }

    Future<void> deleteJob() async {
      final candidates = cvsAsync.value ?? [];
      final confirmed = await showDeleteConfirm(
        context,
        title: 'Delete this job?',
        message: candidates.isEmpty
            ? 'This job has no candidates. It will be permanently removed.'
            : 'This job and its ${candidates.length} '
                '${candidates.length == 1 ? 'candidate' : 'candidates'} '
                'will be permanently removed.',
        details: [jobDeleteDetails(jobAsync.value!, candidates)],
        confirmLabel: 'Delete job',
      );
      if (!confirmed) return;
      try {
        await detailController.deleteJob(jobId);
        if (!context.mounted) return;
        await showActionResult(
          context,
          success: true,
          title: 'Job deleted',
          message: "'${jobAsync.value?.title ?? 'Job'}' was permanently removed.",
        );
      } catch (e) {
        if (!context.mounted) return;
        await showActionResult(
          context,
          success: false,
          title: 'Delete failed',
          message: '$e',
        );
        return;
      }
      if (!context.mounted) return;
      ref.read(navigatorProvider).goToJobs();
    }

    Future<bool> confirmDeleteCv(CandidateResult cv) async {
      final cvId = cv.cvId;
      if (cvId == null) return false;
      final name = cv.candidateName ?? cv.fileName;
      final confirmed = await showDeleteConfirm(
        context,
        title: 'Delete this candidate?',
        message: 'This candidate and their CV will be permanently removed.',
        details: [candidateDeleteDetails(cv)],
        confirmLabel: 'Delete candidate',
      );
      if (!confirmed) return false;
      try {
        await detailController.deleteCv(jobId, cvId);
        if (!context.mounted) return false;
        await showActionResult(
          context,
          success: true,
          title: 'Candidate deleted',
          message: "'$name' and their CV were permanently removed.",
        );
        return true;
      } catch (e) {
        if (!context.mounted) return false;
        await showActionResult(
          context,
          success: false,
          title: 'Delete failed',
          message: '$e',
        );
        return false;
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
          appBar: AppBar(
            title: Text(job.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete job',
                onPressed: detailState.busy ? null : deleteJob,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => detailController.refreshCvs(jobId),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GradientHeader(
                  icon: Icons.work_outline,
                  title: job.title,
                  subtitle: '${cvs.length} CVs uploaded',
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: cardShape(Theme.of(context)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if (job.description.isEmpty)
                          const Text('No description')
                        else
                          _ExpandableSection(
                            maxLines: 10,
                            lineHeight: 22,
                            lineSpacing: 0,
                            child: _DescriptionView(
                              description: job.description,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (job.requirements != null) ...[
                  const SizedBox(height: 16),
                  _RequirementsView(requirements: job.requirements!),
                ],
                const SizedBox(height: 24),
                rankingsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (ranked) {
                    if (ranked.isEmpty) {
                      if (cvs.isEmpty) return const SizedBox.shrink();
                      return const _NotRankedHint();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BucketDonut(buckets: bucketCounts(ranked)),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton.icon(
                            onPressed: () => ref
                                .read(navigatorProvider)
                                .goToRankings(
                                  RankingsScreenData(
                                    jobId: jobId,
                                    jobTitle: job.title,
                                    source: ranked.first.source ?? 'rules',
                                  ),
                                ),
                            icon: const Icon(Icons.timeline),
                            label: const Text('View full ranking'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Candidates (${cvs.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: detailState.busy ? null : pickCvs,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Add CVs'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: detailState.busy ? null : rank,
                        icon: const Icon(Icons.psychology),
                        label: const Text('Rank CVs'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (cvs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No CVs uploaded yet. Tap "Add CVs".'),
                    ),
                  )
                else
                  ...cvs.map(
                        (cv) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Dismissible(
                            key: ValueKey('cv-${cv.cvId ?? cv.fileName}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => confirmDeleteCv(cv),
                            background: _DeleteBackground(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            child: _CandidateTile(cv: cv),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
        if (detailState.busy)
          LoadingOverlay(message: detailState.loadingMessage ?? 'Loading…'),
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

    final content = Column(
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
    );

    return Card(
      elevation: 0,
      shape: cardShape(Theme.of(context)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final Widget child;
  final int maxLines;
  final double lineHeight;
  final double lineSpacing;

  const _ExpandableSection({
    required this.child,
    this.maxLines = 3,
    this.lineHeight = 30,
    this.lineSpacing = 6,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  final GlobalKey _contentKey = GlobalKey();

  bool _expanded = false;
  bool _canExpand = false;

  double get _collapsedHeight =>
      widget.maxLines * widget.lineHeight +
      (widget.maxLines - 1) * widget.lineSpacing;

  void _checkOverflow() {
    final size = _contentKey.currentContext?.size;
    if (size == null) return;
    final can = size.height > _collapsedHeight + 0.5;
    if (can != _canExpand && mounted) {
      setState(() => _canExpand = can);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: _expanded ? double.infinity : _collapsedHeight,
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            clipBehavior: Clip.hardEdge,
            child: KeyedSubtree(
              key: _contentKey,
              child: widget.child,
            ),
          ),
        ),
        if (_canExpand || _expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(_expanded ? 'Show less' : 'Show more'),
            ),
          ),
      ],
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final CandidateResult cv;

  const _CandidateTile({required this.cv});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = cv.candidateName ?? cv.fileName;
    final score = cv.overallScore;
    final color = score == null
        ? candidateColor(cv.cvId ?? name)
        : scoreColor(score);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape(theme),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: score == null
            ? Text(
                cv.status == 'failed' ? 'Failed: ${cv.error}' : cv.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                formatBucket(cv.bucket ?? 'weak_match'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: getBucketColor(cv.bucket ?? 'weak_match'),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: score == null
            ? (cv.status == 'failed' ? const Icon(Icons.error_outline) : null)
            : Text(
                '${(score * 100).round()}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
      ),
    );
  }
}

class _NotRankedHint extends StatelessWidget {
  const _NotRankedHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.insights, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not ranked yet', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Tap "Rank CVs" to score the candidates and see how they compare.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Red swipe-reveal background shown behind a candidate tile during a swipe.
class _DeleteBackground extends StatelessWidget {
  final Color color;

  const _DeleteBackground({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}
