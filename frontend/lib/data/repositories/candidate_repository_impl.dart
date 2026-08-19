import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../domain/models/candidate_page.dart';
import '../../domain/models/candidate_result.dart';
import '../../domain/models/import_result.dart';
import '../../domain/models/rank_response.dart';
import '../../domain/models/upload_file.dart';
import '../../domain/repositories/candidate_repository.dart';
import '../api/response_models.dart';
import '../data_sources/candidate_api_data_source.dart';

@Injectable(as: CandidateRepository)
class CandidateRepositoryImpl implements CandidateRepository {
  CandidateRepositoryImpl(this._dataSource);

  final CandidateApiDataSource _dataSource;

  @override
  Future<ImportResponse> uploadCvBatch(
    String jobId, {
    String? importId,
    required List<UploadFile> files,
    ProgressCallback? onSendProgress,
  }) async {
    final dto = await _dataSource.uploadCvBatch(
      jobId,
      importId: importId,
      files: files,
      onSendProgress: onSendProgress,
    );
    return ImportResponse(
      importId: dto.importId,
      jobId: dto.jobId,
      status: dto.status,
      totalFiles: dto.totalFiles,
      batchFiles: dto.batchFiles,
    );
  }

  @override
  Future<ImportStatus> getImportStatus(String jobId, String importId) async {
    final dto = await _dataSource.getImportStatus(jobId, importId);
    return ImportStatus(
      importId: dto.importId,
      jobId: dto.jobId,
      status: dto.status,
      total: dto.total,
      uploaded: dto.uploaded,
      processed: dto.processed,
      failed: dto.failed,
      pending: dto.pending,
      createdAt: dto.createdAt,
      completedAt: dto.completedAt,
    );
  }

  @override
  Future<List<CandidateResult>> listCvs(String jobId) async {
    final dtos = await _dataSource.listCvs(jobId);
    return dtos.map(_toCandidate).toList();
  }

  @override
  Future<RankResponse> rankJob(String jobId, {String? apiKey}) async {
    final dto = await _dataSource.rankJob(jobId, apiKey: apiKey);
    return RankResponse(
      source: dto.source,
      results: dto.results.map(_toCandidate).toList(),
    );
  }

  @override
  Future<CandidateResult> rankCv(String jobId, String cvId, {String? apiKey}) async {
    return _toCandidate(await _dataSource.rankCv(jobId, cvId, apiKey: apiKey));
  }

  @override
  Future<List<CandidateResult>> getRankings(String jobId) async {
    final dtos = await _dataSource.getRankings(jobId);
    return dtos.map(_toCandidate).toList();
  }

  @override
  Future<void> deleteCandidate(String jobId, String cvId) =>
      _dataSource.deleteCandidate(jobId, cvId);

  @override
  Future<CandidatePage> searchCandidates({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    final dto = await _dataSource.searchCandidates(
      keyword: keyword,
      page: page,
      limit: limit,
    );
    return CandidatePage(
      candidates: dto.candidates.map(_toCandidate).toList(),
      page: dto.page,
      hasMore: dto.hasMore,
    );
  }

  CandidateResult _toCandidate(CandidateResponse dto) {
    return CandidateResult(
      cvId: dto.cvId,
      fileName: dto.fileName,
      status: dto.status,
      candidateName: dto.candidateName,
      overallScore: dto.overallScore,
      bucket: dto.bucket,
      recommendation: dto.recommendation,
      explanation: dto.explanation,
      strengths: dto.strengths,
      weaknesses: dto.weaknesses,
      skillGaps: dto.skillGaps,
      skills: dto.skills,
      yearsExperience: dto.yearsExperience,
      education: dto.education,
      certifications: dto.certifications,
      error: dto.error,
      rank: dto.rank,
      source: dto.source,
      rankedBy: dto.rankedBy,
    );
  }
}
