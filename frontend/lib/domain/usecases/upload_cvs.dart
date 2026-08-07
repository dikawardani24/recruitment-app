import 'package:injectable/injectable.dart';
import 'dart:io';

import '../models/candidate_result.dart';
import '../repositories/candidate_repository.dart';

@Injectable()
class UploadCvs {
  const UploadCvs(this._repository);

  final CandidateRepository _repository;

  Future<List<CandidateResult>> call(String jobId, List<File> files) =>
      _repository.uploadCvs(jobId, files);
}
