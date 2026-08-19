import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../models/import_result.dart';
import '../models/upload_file.dart';
import '../repositories/candidate_repository.dart';

/// Uploads a single batch of CV files to an import job. Batching, progress
/// tracking and retries are handled by the upload controller.
@Injectable()
class UploadCvs {
  const UploadCvs(this._repository);

  final CandidateRepository _repository;

  Future<ImportResponse> call(
    String jobId, {
    String? importId,
    required List<UploadFile> files,
    ProgressCallback? onSendProgress,
  }) => _repository.uploadCvBatch(
    jobId,
    importId: importId,
    files: files,
    onSendProgress: onSendProgress,
  );
}
