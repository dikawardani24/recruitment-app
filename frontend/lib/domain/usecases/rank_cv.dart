import 'package:injectable/injectable.dart';
import '../models/candidate_result.dart';
import '../repositories/candidate_repository.dart';

@Injectable()
class RankCv {
  const RankCv(this._repository);

  final CandidateRepository _repository;

  Future<CandidateResult> call(String jobId, String cvId) =>
      _repository.rankCv(jobId, cvId);
}
