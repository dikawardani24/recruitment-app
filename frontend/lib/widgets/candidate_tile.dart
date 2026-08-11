import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'bucket_donut.dart';
import 'card_shape.dart';
import 'gradient_header.dart';
import 'rank_engine_chip.dart';
import 'score_color.dart';
import 'shimmer.dart';

/// Human-readable label for a candidate's processing/ranking status. Shared by
/// the candidate list tile and the copilot chat cards.
String candidateStatusLabel(CandidateResult cv) {
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

/// A single candidate row: colored avatar, name, ranking bucket/engine (or
/// status) and score. Shared by the job detail candidates list and the
/// copilot chat cards.
class CandidateTile extends StatelessWidget {
  final CandidateResult cv;
  final VoidCallback onShowDetails;

  const CandidateTile({super.key, required this.cv, required this.onShowDetails});

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
        onTap: onShowDetails,
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
                candidateStatusLabel(cv),
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

class CandidateTileSkeleton extends StatelessWidget {
  const CandidateTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape(theme),
      clipBehavior: Clip.antiAlias,
      child: Shimmer(
        child: ListTile(
          leading: const ShimmerBox(width: 44, height: 44, borderRadius: 12),
          title: const ShimmerBox(height: 16, width: double.infinity),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: ShimmerBox(height: 12, width: 140),
          ),
          trailing: const ShimmerBox(width: 32, height: 24, borderRadius: 4),
        ),
      ),
    );
  }
}
