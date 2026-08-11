import 'candidate_result.dart';
import 'job.dart';

/// One structured list payload attached to an assistant message, e.g. the
/// results of "list the jobs" or "who applied?". Rendered as tappable cards
/// that navigate to the entity's detail screen.
class ChatCardGroup {
  /// 'job' | 'candidate'
  final String type;

  /// Populated when [type] is 'job'.
  final List<Job> jobs;

  /// Populated when [type] is 'candidate'.
  final List<CandidateResult> candidates;

  const ChatCardGroup({
    required this.type,
    this.jobs = const [],
    this.candidates = const [],
  });

  bool get isJobs => type == 'job';
}
