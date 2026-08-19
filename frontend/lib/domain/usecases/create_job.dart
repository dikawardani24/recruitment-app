import 'package:injectable/injectable.dart';
import '../models/job.dart';
import '../models/upload_file.dart';
import '../repositories/job_repository.dart';

@Injectable()
class CreateJob {
  const CreateJob(this._repository);

  final JobRepository _repository;

  Future<Job> call({
    required String title,
    required String description,
    UploadFile? jdFile,
  }) => _repository.createJob(
    title: title,
    description: description,
    jdFile: jdFile,
  );
}
