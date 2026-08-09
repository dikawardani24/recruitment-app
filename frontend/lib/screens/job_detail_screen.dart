import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/job_detail_controller.dart';
import '../controllers/upload_controller.dart';
import '../domain/models.dart';
import '../navigation/app_navigator.dart';
import '../providers.dart';
import '../widgets/bucket_donut.dart';
import '../widgets/candidate_detail_sheet.dart';
import '../widgets/cv_upload_overlay.dart';
import '../widgets/gradient_header.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/rank_engine_chip.dart';
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

    final polledCvs = cvsAsync.value ?? const <CandidateResult>[];
    final hasPendingProcessing = polledCvs.any(
      (c) => c.status == 'uploaded' || c.status == 'processing',
    );
    // Poll while candidates are still being processed in the background so the
    // list refreshes on its own. No WebSocket required.
    useEffect(
      () {
        if (!hasPendingProcessing) return null;
        Timer? timer;
        timer = Timer.periodic(const Duration(seconds: 3), (_) {
          final current =
              ref.read(cvsProvider(jobId)).value ?? const <CandidateResult>[];
          final stillPending = current.any(
            (c) => c.status == 'uploaded' || c.status == 'processing',
          );
          if (!stillPending) {
            timer?.cancel();
            return;
          }
          ref.invalidate(cvsProvider(jobId));
        });
        return timer.cancel;
      },
      [jobId, hasPendingProcessing, polledCvs.length],
    );

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
      if (!context.mounted) return;

      // Uploads run in batches and are tracked by [uploadControllerProvider];
      // the overlay closes once the user is done, but extraction continues on
      // the backend regardless.
      ref.read(uploadControllerProvider.notifier).start(jobId, files);
      await showCvUploadOverlay(context, jobId);
      if (!context.mounted) return;
      await detailController.refreshCvs(jobId);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${files.length} CV(s) submitted. Processing continues in the background.',
          ),
        ),
      );
    }

    Future<void> rank() async {
      final messenger = ScaffoldMessenger.of(context);
      final cvs = cvsAsync.value ?? [];

      if (cvs.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('No candidates to rank'),
            content: const Text(
              'Add CVs first, then tap "Rank CVs" to score the candidates.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final allRanked = cvs.every((c) => c.status == 'ranked');
      if (allRanked) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Re-rank all candidates?'),
            content: Text(
              'All ${cvs.length} '
              '${cvs.length == 1 ? 'candidate has' : 'candidates have'} '
              'already been ranked. Re-run ranking on all of them?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Re-rank all'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      final hasReady = cvs.any(
        (c) => c.status == 'completed' || c.status == 'ranked',
      );
      if (!hasReady) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ranking unavailable'),
            content: const Text(
              'No candidates are ready to rank yet. Wait until CV processing '
              'finishes before ranking.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      try {
        await detailController.rank(jobId);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Ranking failed: $e')));
      }
    }

    Future<bool> rankSingle(CandidateResult cv) async {
      final ready = cv.status == 'completed' || cv.status == 'ranked';
      final cvId = cv.cvId;
      if (!ready || cvId == null) {
        if (!context.mounted) return false;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ranking unavailable'),
            content: const Text(
              'This candidate is not ready to rank yet. Wait until CV '
              'processing finishes before ranking.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return false;
      }
      try {
        await detailController.rankCv(jobId, cvId);
        return true;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ranking failed: $e')),
          );
        }
        return false;
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
          message:
              "'${jobAsync.value?.title ?? 'Job'}' was permanently removed.",
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
    final cvs = [...cvsAsync.value ?? const <CandidateResult>[]]
      ..sort(_byRank);

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
                          style: Theme.of(context).textTheme.titleMedium
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
                Card(
                  elevation: 0,
                  shape: cardShape(Theme.of(context)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Ranking',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: detailState.busy ? null : rank,
                          icon: const Icon(Icons.psychology),
                          label: const Text('Rank CVs'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Candidates (${cvs.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (cvs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _CandidateStatusSummary(cvs: cvs),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: detailState.busy ? null : pickCvs,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Add CVs'),
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
                        child: _CandidateTile(
                          cv: cv,
                          onRank: cv.cvId == null
                              ? null
                              : () => rankSingle(cv),
                        ),
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
        .map(
          (w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  void _appendMap(
    StringBuffer buffer,
    Map<dynamic, dynamic> map, {
    required int level,
  }) {
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
      return MarkdownBody(data: md, selectable: true);
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items
                  .map(
                    (s) => Chip(
                      label: Text(s),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
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
      child: Padding(padding: const EdgeInsets.all(16), child: content),
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
            child: KeyedSubtree(key: _contentKey, child: widget.child),
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

/// Orders candidates for the job detail list: ranked first (by score desc),
/// then ready-to-rank, then pending, then failed.
int _byRank(CandidateResult a, CandidateResult b) {
  int priority(CandidateResult c) {
    switch (c.status) {
      case 'ranked':
        return 0;
      case 'completed':
        return 1;
      case 'uploaded':
      case 'processing':
        return 2;
      default:
        return 3;
    }
  }

  final pa = priority(a);
  final pb = priority(b);
  if (pa != pb) return pa.compareTo(pb);
  if (pa == 0) {
    return (b.overallScore ?? 0).compareTo(a.overallScore ?? 0);
  }
  return 0;
}

class _CandidateTile extends StatelessWidget {
  final CandidateResult cv;
  final Future<bool> Function()? onRank;

  const _CandidateTile({required this.cv, this.onRank});

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
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => showCandidateDetailSheet(context, cv, onRank: onRank),
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
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: score == null
            ? Text(
                _candidateStatusLabel(cv),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Row(
                children: [
                  Flexible(
                    child: Text(
                      formatBucket(cv.bucket ?? 'weak_match'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: getBucketColor(cv.bucket ?? 'weak_match'),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RankEngineChip(rankedBy: cv.rankedBy),
                ],
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
    return Row(
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
    );
  }
}

String _candidateStatusLabel(CandidateResult cv) {
  switch (cv.status) {
    case 'completed':
      return 'Ready to rank';
    case 'ranked':
      return 'Ranked';
    case 'processing':
      return 'Processing…';
    case 'uploaded':
      return 'Queued for processing';
    case 'failed':
      return 'Failed: ${cv.error ?? 'unknown error'}';
    default:
      return cv.status;
  }
}

/// Compact ready/processing/failed breakdown for the candidates list.
class _CandidateStatusSummary extends StatelessWidget {
  final List<CandidateResult> cvs;

  const _CandidateStatusSummary({required this.cvs});

  @override
  Widget build(BuildContext context) {
    final ready = cvs.where((c) {
      return c.status == 'completed' || c.status == 'ranked';
    }).length;
    final processing = cvs.where((c) {
      return c.status == 'uploaded' || c.status == 'processing';
    }).length;
    final failed = cvs.where((c) => c.status == 'failed').length;

    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (ready > 0)
          _StatusChip(
            icon: Icons.check_circle_outline,
            label: '$ready ready',
            color: Colors.green.shade700,
            theme: theme,
          ),
        if (processing > 0)
          _StatusChip(
            icon: Icons.sync,
            label: '$processing processing',
            color: theme.colorScheme.primary,
            theme: theme,
          ),
        if (failed > 0)
          _StatusChip(
            icon: Icons.error_outline,
            label: '$failed failed',
            color: theme.colorScheme.error,
            theme: theme,
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ThemeData theme;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Dark-mode safety: hardcoded accent shades like Colors.green.shade700
    // lose contrast on a dark surface, so brighten them toward white.
    final effective = isDark && color.computeLuminance() < 0.3
        ? Color.lerp(color, Colors.white, 0.25)!
        : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: effective.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: effective),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: effective,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
