import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'card_shape.dart';
import 'gradient_header.dart';
import 'shimmer.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatCreatedAt(String? iso) {
  final date = iso == null ? null : DateTime.tryParse(iso);
  if (date == null) return '';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = _months[local.month - 1];
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'am' : 'pm';
  return '$day $month ${local.year} $hour12:$minute $period';
}

class JobCard extends StatelessWidget {
  final Job job;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onAddCandidate;

  const JobCard({
    super.key,
    required this.job,
    required this.index,
    required this.onTap,
    this.onAddCandidate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = avatarColor(index);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape(theme),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.work_outline, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            formatCreatedAt(job.createdAt),
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${job.candidateCount} candidates',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (onAddCandidate != null) ...[
                          const SizedBox(width: 8),
                          Text('·', style: theme.textTheme.labelSmall),
                          TextButton(
                            onPressed: onAddCandidate,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Add Candidate'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class JobCardSkeleton extends StatelessWidget {
  const JobCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape(theme),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer(
          child: Row(
            children: [
              const ShimmerBox(width: 48, height: 48, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(height: 16, width: double.infinity),
                    SizedBox(height: 12),
                    ShimmerBox(height: 12, width: 140),
                    SizedBox(height: 12),
                    ShimmerBox(height: 12, width: 96),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const ShimmerBox(width: 20, height: 20, borderRadius: 10),
            ],
          ),
        ),
      ),
    );
  }
}
