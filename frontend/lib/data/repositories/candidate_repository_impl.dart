import 'dart:io';

import 'package:injectable/injectable.dart';

import '../../domain/models/candidate_result.dart';
import '../../domain/models/rank_response.dart';
import '../../domain/repositories/candidate_repository.dart';
import '../api/response_models.dart';
import '../data_sources/candidate_api_data_source.dart';

@Injectable(as: CandidateRepository)
class CandidateRepositoryImpl implements CandidateRepository {
  CandidateRepositoryImpl(this._dataSource);

  final CandidateApiDataSource _dataSource;

  @override
  Future<List<CandidateResult>> uploadCvs(
    String jobId,
    List<File> files,
  ) async {
    final dtos = await _dataSource.uploadCvs(jobId, files);
    return dtos.map(_toCandidate).toList();
  }

  @override
  Future<List<CandidateResult>> listCvs(String jobId) async {
    final dtos = await _dataSource.listCvs(jobId);
    return dtos.map(_toCandidate).toList();
  }

  @override
  Future<RankResponse> rankJob(String jobId) async {
    final dto = await _dataSource.rankJob(jobId);
    return RankResponse(
      source: dto.source,
      results: dto.results.map(_toCandidate).toList(),
    );
  }

  @override
  Future<CandidateResult> rankCv(String jobId, String cvId) async {
    return _toCandidate(await _dataSource.rankCv(jobId, cvId));
  }

  @override
  Future<List<CandidateResult>> getRankings(String jobId) async {
    final dtos = await _dataSource.getRankings(jobId);
    return dtos.map(_toCandidate).toList();
  }

  @override
  Future<void> deleteCandidate(String jobId, String cvId) =>
      _dataSource.deleteCandidate(jobId, cvId);

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
