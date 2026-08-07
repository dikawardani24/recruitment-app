import 'package:injectable/injectable.dart';
import '../models/job.dart';
import '../repositories/job_repository.dart';

@Injectable()
class GetJob {
  const GetJob(this._repository);

  final JobRepository _repository;

  Future<Job> call(String jobId) => _repository.getJob(jobId);
}
