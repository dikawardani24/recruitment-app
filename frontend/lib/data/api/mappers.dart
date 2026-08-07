import 'response_models.dart';

class JobRequirementsResponseMapper {
  JobRequirementsResponseMapper._();

  static JobRequirementsResponse fromJson(Map<String, dynamic> json) {
    return JobRequirementsResponse(
      title: json['title'] as String?,
      requiredSkills: _stringList(json['required_skills']),
      preferredSkills: _stringList(json['preferred_skills']),
      minYears: (json['min_years'] as num?)?.toDouble() ?? 0,
      education: json['education'] as String?,
      certifications: _stringList(json['certifications']),
      responsibilities: _stringList(json['responsibilities']),
    );
  }
}

class JobResponseMapper {
  JobResponseMapper._();

  static JobResponse fromJson(Map<String, dynamic> json) {
    final req = json['requirements'];
    return JobResponse(
      jobId: json['job_id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      status: json['status'] as String,
      createdAt: (json['created_at'] as String?) ?? '',
      cvCount: (json['cv_count'] as num?)?.toInt() ?? 0,
      requirements: req is Map<String, dynamic>
          ? JobRequirementsResponseMapper.fromJson(req)
          : null,
    );
  }
}

class CandidateResponseMapper {
  CandidateResponseMapper._();

  static CandidateResponse fromJson(Map<String, dynamic> json) {
    return CandidateResponse(
      cvId: json['cv_id'] as String?,
      fileName: (json['file_name'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      candidateName: json['candidate_name'] as String?,
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      bucket: json['bucket'] as String?,
      recommendation: json['recommendation'] as String?,
      explanation: json['explanation'] as String?,
      strengths: _stringList(json['strengths']),
      weaknesses: _stringList(json['weaknesses']),
      skillGaps: _stringList(json['skill_gaps']),
      skills: _stringList(json['skills']),
      yearsExperience: (json['years_experience'] as num?)?.toDouble(),
      education: json['education'] as String?,
      certifications: _stringList(json['certifications']),
      error: json['error'] as String?,
      rank: json['rank'] as int?,
      source: json['source'] as String?,
      rankedBy: json['ranked_by'] as String?,
    );
  }
}

class JobPageResponseMapper {
  JobPageResponseMapper._();

  static JobPageResponse fromJson(
    Map<String, dynamic> envelope, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final jobs = ((envelope['jobs'] as List?) ?? [])
        .map((e) => JobResponseMapper.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = envelope['meta'] as Map<String, dynamic>? ?? const {};
    final hasMore = (meta['has_more'] as bool?) ?? jobs.length >= fallbackLimit;
    return JobPageResponse(
      jobs: jobs,
      page: (meta['page'] as num?)?.toInt() ?? fallbackPage,
      hasMore: hasMore && jobs.isNotEmpty,
    );
  }
}

class RankResponseMapper {
  RankResponseMapper._();

  static RankResponseDto fromJson(Map<String, dynamic> envelope) {
    final results = ((envelope['results'] as List?) ?? [])
        .map((e) => CandidateResponseMapper.fromJson(e as Map<String, dynamic>))
        .toList();
    return RankResponseDto(
      source: (envelope['source'] as String?) ?? 'rules',
      results: results,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
}
