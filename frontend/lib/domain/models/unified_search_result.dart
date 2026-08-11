import 'candidate_result.dart';
import 'job.dart';

class UnifiedSearchResult {
  final String keyword;
  final List<Job> jobs;
  final bool jobsHasMore;
  final List<CandidateResult> candidates;
  final bool candidatesHasMore;

  const UnifiedSearchResult({
    required this.keyword,
    required this.jobs,
    required this.jobsHasMore,
    required this.candidates,
    required this.candidatesHasMore,
  });

  bool get isEmpty => jobs.isEmpty && candidates.isEmpty;
}
