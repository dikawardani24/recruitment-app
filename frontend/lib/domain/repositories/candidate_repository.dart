import 'package:dio/dio.dart';

import '../models/candidate_page.dart';
import '../models/candidate_result.dart';
import '../models/import_result.dart';
import '../models/rank_response.dart';
import '../models/upload_file.dart';

abstract class CandidateRepository {
  Future<ImportResponse> uploadCvBatch(
    String jobId, {
    String? importId,
    required List<UploadFile> files,
    ProgressCallback? onSendProgress,
  });

  Future<ImportStatus> getImportStatus(String jobId, String importId);

  Future<List<CandidateResult>> listCvs(String jobId);

  Future<RankResponse> rankJob(String jobId);

  Future<CandidateResult> rankCv(String jobId, String cvId);

  Future<List<CandidateResult>> getRankings(String jobId);

  Future<void> deleteCandidate(String jobId, String cvId);

  Future<CandidatePage> searchCandidates({
    required String keyword,
    required int page,
    required int limit,
  });
}
