class JobRequirementsResponse {
  final String? title;
  final List<String> requiredSkills;
  final List<String> preferredSkills;
  final double minYears;
  final String? education;
  final List<String> certifications;
  final List<String> responsibilities;

  const JobRequirementsResponse({
    this.title,
    required this.requiredSkills,
    required this.preferredSkills,
    required this.minYears,
    this.education,
    required this.certifications,
    required this.responsibilities,
  });
}

class JobResponse {
  final String jobId;
  final String title;
  final String description;
  final String status;
  final String createdAt;
  final int cvCount;
  final JobRequirementsResponse? requirements;

  const JobResponse({
    required this.jobId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.cvCount = 0,
    this.requirements,
  });
}

class CandidateResponse {
  final String? cvId;
  final String fileName;
  final String status;
  final String? candidateName;
  final double? overallScore;
  final String? bucket;
  final String? recommendation;
  final String? explanation;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> skillGaps;
  final List<String> skills;
  final double? yearsExperience;
  final String? education;
  final List<String> certifications;
  final String? error;
  final int? rank;
  final String? source;
  final String? rankedBy;

  const CandidateResponse({
    this.cvId,
    required this.fileName,
    required this.status,
    this.candidateName,
    this.overallScore,
    this.bucket,
    this.recommendation,
    this.explanation,
    required this.strengths,
    required this.weaknesses,
    required this.skillGaps,
    required this.skills,
    this.yearsExperience,
    this.education,
    required this.certifications,
    this.error,
    this.rank,
    this.source,
    this.rankedBy,
  });
}

class JobPageResponse {
  final List<JobResponse> jobs;
  final int page;
  final bool hasMore;

  const JobPageResponse({
    required this.jobs,
    required this.page,
    required this.hasMore,
  });
}

class ImportResponseDto {
  final String importId;
  final String jobId;
  final String status;
  final int totalFiles;
  final int batchFiles;

  const ImportResponseDto({
    required this.importId,
    required this.jobId,
    required this.status,
    required this.totalFiles,
    required this.batchFiles,
  });
}

class ImportStatusDto {
  final String importId;
  final String jobId;
  final String status;
  final int total;
  final int uploaded;
  final int processed;
  final int failed;
  final int pending;
  final String? createdAt;
  final String? completedAt;

  const ImportStatusDto({
    required this.importId,
    required this.jobId,
    required this.status,
    required this.total,
    required this.uploaded,
    required this.processed,
    required this.failed,
    required this.pending,
    this.createdAt,
    this.completedAt,
  });
}

class RankResponseDto {
  final String source;
  final List<CandidateResponse> results;

  const RankResponseDto({required this.source, required this.results});
}
