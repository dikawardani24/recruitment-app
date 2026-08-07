import 'package:injectable/injectable.dart';
import '../models/candidate_result.dart';
import '../repositories/candidate_repository.dart';

@Injectable()
class GetRankings {
  const GetRankings(this._repository);

  final CandidateRepository _repository;

  Future<List<CandidateResult>> call(String jobId) =>
      _repository.getRankings(jobId);
}
