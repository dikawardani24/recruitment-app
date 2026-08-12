import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/data/api/api_client.dart';
import 'package:ai_ats/data/api/response_models.dart';
import 'package:ai_ats/data/data_sources/search_api_data_source.dart';
import 'package:ai_ats/data/repositories/search_repository_impl.dart';

class _FakeSearchDataSource extends SearchApiDataSource {
  _FakeSearchDataSource() : super(ApiClient(dio: Dio()));

  final calls = <({String keyword, int limit})>[];
  late UnifiedSearchResponse response;

  @override
  Future<UnifiedSearchResponse> unifiedSearch({
    required String keyword,
    required int limit,
  }) async {
    calls.add((keyword: keyword, limit: limit));
    return response;
  }
}

UnifiedSearchResponse _response() {
  return UnifiedSearchResponse(
    keyword: 'engineer',
    jobs: [
      JobResponse(
        jobId: 'j1',
        title: 'Backend Engineer',
        description: 'Build services',
        status: 'open',
        createdAt: '2026-08-06T14:05:00',
        cvCount: 3,
        requirements: JobRequirementsResponse(
          title: 'Backend Engineer',
          requiredSkills: ['Dart', 'PostgreSQL'],
          preferredSkills: ['gRPC'],
          minYears: 3,
          education: 'BSc',
          certifications: ['AWS'],
          responsibilities: ['Design APIs'],
        ),
      ),
      JobResponse(
        jobId: 'j2',
        title: 'Frontend Engineer',
        description: 'Build UI',
        status: 'open',
        createdAt: '2026-08-07T14:05:00',
        cvCount: 0,
        requirements: null,
      ),
    ],
    jobsHasMore: true,
    candidates: [
      CandidateResponse(
        cvId: 'c1',
        jobId: 'j1',
        fileName: 'alice.pdf',
        status: 'ranked',
        candidateName: 'Alice',
        overallScore: 0.87,
        bucket: 'strong_match',
        recommendation: 'Hire',
        explanation: 'Matches requirements',
        strengths: ['Dart'],
        weaknesses: ['No gRPC'],
        skillGaps: ['Kubernetes'],
        skills: ['Dart', 'Flutter'],
        yearsExperience: 4,
        education: 'MSc',
        certifications: ['AWS'],
        error: null,
        rank: 1,
        source: 'rules',
        rankedBy: 'llm',
      ),
    ],
    candidatesHasMore: false,
  );
}

void main() {
  test('unifiedSearch forwards the keyword and limit to the data source', () async {
    final source = _FakeSearchDataSource()..response = _response();
    final repo = SearchRepositoryImpl(source);

    final result = await repo.unifiedSearch(keyword: 'engineer', limit: 8);

    expect(source.calls.single.keyword, 'engineer');
    expect(source.calls.single.limit, 8);
    expect(result.keyword, 'engineer');
    expect(result.jobsHasMore, isTrue);
    expect(result.candidatesHasMore, isFalse);
  });

  test('maps a job with requirements', () async {
    final source = _FakeSearchDataSource()..response = _response();
    final repo = SearchRepositoryImpl(source);

    final job = (await repo.unifiedSearch(keyword: 'engineer')).jobs.first;

    expect(job.id, 'j1');
    expect(job.title, 'Backend Engineer');
    expect(job.description, 'Build services');
    expect(job.status, 'open');
    expect(job.createdAt, '2026-08-06T14:05:00');
    expect(job.candidateCount, 3);
    expect(job.requirements, isNotNull);
    expect(job.requirements!.title, 'Backend Engineer');
    expect(job.requirements!.requiredSkills, ['Dart', 'PostgreSQL']);
    expect(job.requirements!.preferredSkills, ['gRPC']);
    expect(job.requirements!.minYears, 3);
    expect(job.requirements!.education, 'BSc');
    expect(job.requirements!.certifications, ['AWS']);
    expect(job.requirements!.responsibilities, ['Design APIs']);
  });

  test('leaves requirements null when the response has none', () async {
    final source = _FakeSearchDataSource()..response = _response();
    final repo = SearchRepositoryImpl(source);

    final job = (await repo.unifiedSearch(keyword: 'engineer')).jobs[1];

    expect(job.requirements, isNull);
    expect(job.candidateCount, 0);
  });

  test('maps a candidate with its ranking details', () async {
    final source = _FakeSearchDataSource()..response = _response();
    final repo = SearchRepositoryImpl(source);

    final candidate = (await repo.unifiedSearch(keyword: 'engineer')).candidates.single;

    expect(candidate.cvId, 'c1');
    expect(candidate.jobId, 'j1');
    expect(candidate.fileName, 'alice.pdf');
    expect(candidate.status, 'ranked');
    expect(candidate.candidateName, 'Alice');
    expect(candidate.overallScore, 0.87);
    expect(candidate.bucket, 'strong_match');
    expect(candidate.recommendation, 'Hire');
    expect(candidate.explanation, 'Matches requirements');
    expect(candidate.strengths, ['Dart']);
    expect(candidate.weaknesses, ['No gRPC']);
    expect(candidate.skillGaps, ['Kubernetes']);
    expect(candidate.skills, ['Dart', 'Flutter']);
    expect(candidate.yearsExperience, 4);
    expect(candidate.education, 'MSc');
    expect(candidate.certifications, ['AWS']);
    expect(candidate.rank, 1);
    expect(candidate.source, 'rules');
    expect(candidate.rankedBy, 'llm');
  });
}
