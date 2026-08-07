import 'package:injectable/injectable.dart';
import '../repositories/job_repository.dart';

@Injectable()
class DeleteJob {
  const DeleteJob(this._repository);

  final JobRepository _repository;

  Future<void> call(String jobId) => _repository.deleteJob(jobId);
}
