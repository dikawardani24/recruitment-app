import 'package:injectable/injectable.dart';

import '../../domain/models/candidate_result.dart';
import '../../domain/models/job.dart';
import '../../domain/models/job_requirements.dart';
import '../../domain/models/unified_search_result.dart';
import '../../domain/repositories/search_repository.dart';
import '../api/response_models.dart';
import '../data_sources/search_api_data_source.dart';

@Injectable(as: SearchRepository)
class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._dataSource);

  final SearchApiDataSource _dataSource;

  @override
  Future<UnifiedSearchResult> unifiedSearch({
    required String keyword,
    int limit = 5,
  }) async {
    final dto = await _dataSource.unifiedSearch(keyword: keyword, limit: limit);
    return UnifiedSearchResult(
      keyword: dto.keyword,
      jobs: dto.jobs.map(_toJob).toList(),
      jobsHasMore: dto.jobsHasMore,
      candidates: dto.candidates.map(_toCandidate).toList(),
      candidatesHasMore: dto.candidatesHasMore,
    );
  }

  Job _toJob(JobResponse dto) {
    return Job(
      id: dto.jobId,
      title: dto.title,
      description: dto.description,
      status: dto.status,
      createdAt: dto.createdAt,
      candidateCount: dto.cvCount,
      requirements: dto.requirements == null
          ? null
          : JobRequirements(
              title: dto.requirements!.title,
              requiredSkills: dto.requirements!.requiredSkills,
              preferredSkills: dto.requirements!.preferredSkills,
              minYears: dto.requirements!.minYears,
              education: dto.requirements!.education,
              certifications: dto.requirements!.certifications,
              responsibilities: dto.requirements!.responsibilities,
            ),
    );
  }

  CandidateResult _toCandidate(CandidateResponse dto) {
    return CandidateResult(
      cvId: dto.cvId,
      jobId: dto.jobId,
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
