class JobRequirements {
  final String? title;
  final List<String> requiredSkills;
  final List<String> preferredSkills;
  final double minYears;
  final String? education;
  final List<String> certifications;
  final List<String> responsibilities;

  const JobRequirements({
    this.title,
    this.requiredSkills = const [],
    this.preferredSkills = const [],
    this.minYears = 0,
    this.education,
    this.certifications = const [],
    this.responsibilities = const [],
  });

  factory JobRequirements.fromJson(Map<String, dynamic> json) {
    return JobRequirements(
      title: json['title'] as String?,
      requiredSkills: _stringList(json['required_skills']),
      preferredSkills: _stringList(json['preferred_skills']),
      minYears: (json['min_years'] as num?)?.toDouble() ?? 0,
      education: json['education'] as String?,
      certifications: _stringList(json['certifications']),
      responsibilities: _stringList(json['responsibilities']),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }
}

class Job {
  final String id;
  final String title;
  final String description;
  final String status;
  final String createdAt;
  final int candidateCount;
  final JobRequirements? requirements;

  const Job({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.candidateCount = 0,
    this.requirements,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final req = json['requirements'];
    return Job(
      id: json['job_id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      status: json['status'] as String,
      createdAt: (json['created_at'] as String?) ?? '',
      candidateCount: (json['cv_count'] as num?)?.toInt() ?? 0,
      requirements: req is Map<String, dynamic>
          ? JobRequirements.fromJson(req)
          : null,
    );
  }
}

class CandidateResult {
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

  const CandidateResult({
    this.cvId,
    required this.fileName,
    required this.status,
    this.candidateName,
    this.overallScore,
    this.bucket,
    this.recommendation,
    this.explanation,
    this.strengths = const [],
    this.weaknesses = const [],
    this.skillGaps = const [],
    this.skills = const [],
    this.yearsExperience,
    this.education,
    this.certifications = const [],
    this.error,
    this.rank,
    this.source,
    this.rankedBy,
  });

  factory CandidateResult.fromJson(Map<String, dynamic> json) {
    return CandidateResult(
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

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }
}
