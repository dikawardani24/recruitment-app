import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/jobDetail/job_detail_controller.dart';
import '../controllers/jobDetail/job_detail_notifier.dart';
import '../domain/models.dart';
import '../providers.dart';
import '../widgets/bucket_donut.dart';
import '../widgets/candidate_tile.dart';
import '../widgets/delete_background.dart';
import '../widgets/deferred_page.dart';
import '../widgets/gradient_header.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/section_card.dart';

class JobDetailScreen extends ConsumerWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off the job/CV fetches during the transition so only the heavy UI
    // build is deferred, not the network requests.
    ref.watch(jobProvider(jobId));
    ref.watch(cvsProvider(jobId));
    return DeferredPage(child: _JobDetailContent(jobId: jobId));
  }
}

class _JobDetailContent extends HookConsumerWidget {
  final String jobId;

  const _JobDetailContent({required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobProvider(jobId));
    final cvsAsync = ref.watch(cvsProvider(jobId));

    final detailState = ref.watch(jobDetailStateProvider);
    final detailController = ref.read(jobDetailControllerProvider);

    // Periodic polling is owned by the detail notifier and is started only
    // after a successful import. This cleanup prevents it surviving the page.
    useEffect(() {
      return () => detailController.stopPolling(jobId);
    }, [jobId, detailController]);

    final job = jobAsync.value;
    final cvs = [...cvsAsync.value ?? const <CandidateResult>[]]..sort(_byRank);

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
                onPressed: detailState.busy
                    ? null
                    : () => detailController.deleteJob(
                        jobId,
                        job,
                        cvsAsync.value ?? const [],
                      ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => detailController.refreshCvs(jobId),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _JobHeader(job: job, cvsCount: cvs.length),
                const SizedBox(height: 16),
                _JobDescriptionSection(job: job),
                if (job.requirements != null) ...[
                  const SizedBox(height: 16),
                  _RequirementsSection(requirements: job.requirements!),
                ],
                const SizedBox(height: 24),
                _RankingSection(jobId: jobId, jobTitle: job.title),
                const SizedBox(height: 24),
                _CandidatesSection(jobId: jobId),
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

/// 1. Header — the job's gradient hero with the uploaded-CV count.
class _JobHeader extends StatelessWidget {
  final Job job;
  final int cvsCount;

  const _JobHeader({required this.job, required this.cvsCount});

  @override
  Widget build(BuildContext context) {
    return GradientHeader(
      icon: Icons.work_outline,
      title: job.title,
      subtitle: '$cvsCount CVs uploaded',
    );
  }
}

/// 2. Job Description — the markdown/JSON description in a collapsible card.
class _JobDescriptionSection extends StatelessWidget {
  final Job job;

  const _JobDescriptionSection({required this.job});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Description',
      child: job.description.isEmpty
          ? const Text('No description')
          : _ExpandableSection(
              maxLines: 10,
              lineHeight: 22,
              lineSpacing: 0,
              child: _DescriptionView(description: job.description),
            ),
    );
  }
}

/// 3. Required Skills — the parsed job requirements as labelled chip groups.
class _RequirementsSection extends StatelessWidget {
  final JobRequirements requirements;

  const _RequirementsSection({required this.requirements});

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

    return SectionCard(
      title: 'Requirements',
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
    );
  }
}

/// 4. Ranking — the bucket donut (or a "not ranked yet" hint) and the
/// "Rank CVs" action.
class _RankingSection extends ConsumerWidget {
  final String jobId;
  final String jobTitle;

  const _RankingSection({required this.jobId, required this.jobTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cvs =
        ref.watch(cvsProvider(jobId)).value ?? const <CandidateResult>[];
    final detailState = ref.watch(jobDetailStateProvider);
    final detailController = ref.read(jobDetailControllerProvider);

    // Ranked candidates come from the already-loaded CV list; no extra
    // rankings fetch on screen open (the full-ranking screen loads its own).
    final ranked = cvs
        .where((c) => c.overallScore != null)
        .toList(growable: false);
    final hasRankings = ranked.isNotEmpty;

    return SectionCard(
      title: 'Ranking',
      crossAxisAlignment: CrossAxisAlignment.stretch,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ranked.isEmpty)
            cvs.isEmpty ? const SizedBox.shrink() : const _NotRankedHint()
          else
            BucketDonut(buckets: bucketCounts(ranked)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (hasRankings) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: detailState.busy
                        ? null
                        : () => detailController.viewRankings(
                            jobId,
                            jobTitle,
                            ranked.first.source ?? 'rules',
                          ),
                    icon: const Icon(Icons.timeline),
                    label: const Text('View full ranking'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: detailState.busy
                      ? null
                      : () => detailController.rank(context, jobId, cvs),
                  icon: const Icon(Icons.psychology),
                  label: const Text('Rank CVs'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 5. Candidates — the "Candidates (n)" header, status summary, "Add CVs"
/// button, and the swipe-to-delete candidate tiles.
class _CandidatesSection extends ConsumerWidget {
  final String jobId;

  const _CandidatesSection({required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cvsAsync = ref.watch(cvsProvider(jobId));
    final cvs = [...cvsAsync.value ?? const <CandidateResult>[]]..sort(_byRank);
    final detailState = ref.watch(jobDetailStateProvider);
    final detailController = ref.read(jobDetailControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          onPressed: detailState.busy
              ? null
              : () => detailController.pickCvs(context, jobId),
          icon: const Icon(Icons.upload_file),
          label: const Text('Add CVs'),
        ),
        const SizedBox(height: 12),
        if (cvs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No CVs uploaded yet. Tap "Add CVs".')),
          )
        else
          ...cvs.map(
            (cv) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey('cv-${cv.cvId ?? cv.fileName}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => detailController.deleteCv(jobId, cv),
                background: DeleteBackground(
                  color: Theme.of(context).colorScheme.error,
                ),
                child: CandidateTile(
                  cv: cv,
                  onShowDetails: () =>
                      detailController.openCandidateDetails(context, jobId, cv),
                ),
              ),
            ),
          ),
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
