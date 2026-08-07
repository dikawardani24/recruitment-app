import 'package:injectable/injectable.dart';
import '../models/rank_response.dart';
import '../repositories/candidate_repository.dart';

@Injectable()
class RankJob {
  const RankJob(this._repository);

  final CandidateRepository _repository;

  Future<RankResponse> call(String jobId) => _repository.rankJob(jobId);
}
