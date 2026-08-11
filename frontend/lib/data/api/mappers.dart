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

class CandidatePageResponseMapper {
  CandidatePageResponseMapper._();

  static CandidatePageResponse fromJson(
    Map<String, dynamic> envelope, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final candidates = ((envelope['candidates'] as List?) ?? [])
        .map((e) => CandidateResponseMapper.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = envelope['meta'] as Map<String, dynamic>? ?? const {};
    final hasMore =
        (meta['has_more'] as bool?) ?? candidates.length >= fallbackLimit;
    return CandidatePageResponse(
      candidates: candidates,
      page: (meta['page'] as num?)?.toInt() ?? fallbackPage,
      hasMore: hasMore && candidates.isNotEmpty,
    );
  }
}

class UnifiedSearchResponseMapper {
  UnifiedSearchResponseMapper._();

  static UnifiedSearchResponse fromJson(Map<String, dynamic> json) {
    final jobsData = json['jobs'] as Map<String, dynamic>? ?? const {};
    final cvsData = json['candidates'] as Map<String, dynamic>? ?? const {};

    final jobs = ((jobsData['data'] as List?) ?? [])
        .map((e) => JobResponseMapper.fromJson(e as Map<String, dynamic>))
        .toList();
    final candidates = ((cvsData['data'] as List?) ?? [])
        .map((e) => CandidateResponseMapper.fromJson(e as Map<String, dynamic>))
        .toList();

    return UnifiedSearchResponse(
      keyword: (json['keyword'] as String?) ?? '',
      jobs: jobs,
      jobsHasMore: (jobsData['has_more'] as bool?) ?? false,
      candidates: candidates,
      candidatesHasMore: (cvsData['has_more'] as bool?) ?? false,
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

class ImportResponseMapper {
  ImportResponseMapper._();

  static ImportResponseDto fromJson(Map<String, dynamic> json) {
    return ImportResponseDto(
      importId: json['import_id'] as String,
      jobId: (json['job_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'submitted',
      totalFiles: (json['total_files'] as num?)?.toInt() ?? 0,
      batchFiles: (json['batch_files'] as num?)?.toInt() ?? 0,
    );
  }
}

class ImportStatusMapper {
  ImportStatusMapper._();

  static ImportStatusDto fromJson(Map<String, dynamic> json) {
    return ImportStatusDto(
      importId: json['import_id'] as String,
      jobId: (json['job_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      uploaded: (json['uploaded'] as num?)?.toInt() ?? 0,
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }
}

class ChatResponseMapper {
  ChatResponseMapper._();

  static ChatResponseDto fromJson(Map<String, dynamic> json) {
    final sources = ((json['sources'] as List?) ?? [])
        .map((e) => ChatSourceResponseMapper.fromJson(e as Map<String, dynamic>))
        .toList();
    final cards = ((json['cards'] as List?) ?? [])
        .map((e) => ChatCardResponseMapper.fromJson(e as Map<String, dynamic>))
        .toList();
    final retrieval = json['retrieval'] as Map<String, dynamic>? ?? const {};
    return ChatResponseDto(
      configured: (json['configured'] as bool?) ?? false,
      answer: (json['answer'] as String?) ?? '',
      sources: sources,
      cards: cards,
      retrievalEnabled: (retrieval['enabled'] as bool?) ?? false,
      retrievalCount: (retrieval['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatCardResponseMapper {
  ChatCardResponseMapper._();

  static ChatCardResponse fromJson(Map<String, dynamic> json) {
    final items = ((json['items'] as List?) ?? []).whereType<Map<String, dynamic>>();
    final type = (json['type'] as String?) ?? 'candidate';
    return ChatCardResponse(
      type: type,
      jobs: type == 'job'
          ? items.map((e) => ChatJobCardItemMapper.fromJson(e)).toList()
          : const [],
      candidates: type == 'candidate'
          ? items.map((e) => ChatCandidateCardItemMapper.fromJson(e)).toList()
          : const [],
    );
  }
}

class ChatJobCardItemMapper {
  ChatJobCardItemMapper._();

  static JobResponse fromJson(Map<String, dynamic> json) {
    return JobResponse(
      jobId: (json['job_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: '',
      status: (json['status'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
      cvCount: (json['candidate_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatCandidateCardItemMapper {
  ChatCandidateCardItemMapper._();

  static CandidateResponse fromJson(Map<String, dynamic> json) {
    return CandidateResponse(
      cvId: json['cv_id'] as String?,
      jobId: json['job_id'] as String?,
      fileName: (json['file_name'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      candidateName: (json['name'] as String?) ?? json['candidate_name'] as String?,
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      bucket: json['bucket'] as String?,
      rankedBy: json['ranked_by'] as String?,
      strengths: const [],
      weaknesses: const [],
      skillGaps: const [],
      skills: _stringList(json['skills']),
      certifications: const [],
    );
  }
}

class ChatSourceResponseMapper {
  ChatSourceResponseMapper._();

  static ChatSourceResponse fromJson(Map<String, dynamic> json) {
    return ChatSourceResponse(
      entityType: (json['entity_type'] as String?) ?? 'candidate',
      entityId: (json['entity_id'] as String?) ?? '',
      jobId: json['job_id'] as String?,
      name: (json['entity_name'] as String?) ?? '',
      section: (json['section'] as String?) ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ChatModelsMapper {
  ChatModelsMapper._();

  static List<ChatModelDto> fromJson(Map<String, dynamic> json) {
    return ((json['models'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => ChatModelDto(
            id: (e['id'] as String?) ?? '',
            label: (e['label'] as String?) ?? '',
            provider: (e['provider'] as String?) ?? '',
            model: (e['model'] as String?) ?? '',
          ),
        )
        .where((m) => m.id.isNotEmpty)
        .toList();
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
}
