import 'package:injectable/injectable.dart';
import 'dart:io';

import '../models/job.dart';
import '../repositories/job_repository.dart';

@Injectable()
class CreateJob {
  const CreateJob(this._repository);

  final JobRepository _repository;

  Future<Job> call({
    required String title,
    required String description,
    File? jdFile,
    String? jdFileName,
  }) =>
      _repository.createJob(
        title: title,
        description: description,
        jdFile: jdFile,
        jdFileName: jdFileName,
      );
}
