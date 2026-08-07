import 'package:injectable/injectable.dart';
import '../repositories/candidate_repository.dart';

@Injectable()
class DeleteCandidate {
  const DeleteCandidate(this._repository);

  final CandidateRepository _repository;

  Future<void> call(String jobId, String cvId) =>
      _repository.deleteCandidate(jobId, cvId);
}
