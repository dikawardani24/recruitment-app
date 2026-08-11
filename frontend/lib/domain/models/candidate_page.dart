import 'candidate_result.dart';

class CandidatePage {
  final List<CandidateResult> candidates;
  final int page;
  final bool hasMore;

  const CandidatePage({
    required this.candidates,
    required this.page,
    required this.hasMore,
  });
}
