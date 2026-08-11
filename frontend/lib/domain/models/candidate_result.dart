class CandidateResult {
  final String? cvId;
  final String? jobId;
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
    this.jobId,
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
}
