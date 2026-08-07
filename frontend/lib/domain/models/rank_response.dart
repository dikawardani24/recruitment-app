import 'candidate_result.dart';

class RankResponse {
  final String source;
  final List<CandidateResult> results;

  const RankResponse({required this.source, required this.results});
}
