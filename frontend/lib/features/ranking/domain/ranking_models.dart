enum RankingBucket { best, strong, hiddenGem, alternative }

class ScoreCard {
  ScoreCard({
    required this.skillMatch,
    required this.experienceMatch,
    required this.educationMatch,
    required this.certificationMatch,
  });

  final double skillMatch;
  final double experienceMatch;
  final double educationMatch;
  final double certificationMatch;

  factory ScoreCard.fromJson(Map<String, dynamic> json) => ScoreCard(
        skillMatch: (json['skill_match'] as num?)?.toDouble() ?? 0,
        experienceMatch: (json['experience_match'] as num?)?.toDouble() ?? 0,
        educationMatch: (json['education_match'] as num?)?.toDouble() ?? 0,
        certificationMatch: (json['certification_match'] as num?)?.toDouble() ?? 0,
      );
}

class EvidenceChunk {
  EvidenceChunk({
    required this.chunkId,
    required this.section,
    required this.score,
    required this.text,
  });

  final String chunkId;
  final String section;
  final double score;
  final String text;

  factory EvidenceChunk.fromJson(Map<String, dynamic> json) => EvidenceChunk(
        chunkId: json['chunk_id'] as String,
        section: json['section'] as String,
        score: (json['score'] as num?)?.toDouble() ?? 0,
        text: json['text'] as String? ?? '',
      );
}

class RankedCandidate {
  RankedCandidate({
    required this.candidateId,
    required this.candidateName,
    required this.bucket,
    required this.overallScore,
    required this.scores,
    required this.explanation,
    required this.evidence,
  });

  final String candidateId;
  final String candidateName;
  final RankingBucket bucket;
  final double overallScore;
  final ScoreCard scores;
  final String explanation;
  final List<EvidenceChunk> evidence;

  factory RankedCandidate.fromJson(Map<String, dynamic> json) => RankedCandidate(
        candidateId: json['candidate_id'] as String,
        candidateName: json['candidate_name'] as String? ?? '',
        bucket: _bucketFrom(json['bucket']),
        overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0,
        scores: ScoreCard.fromJson(json['scores'] as Map<String, dynamic>? ?? {}),
        explanation: json['explanation'] as String? ?? '',
        evidence: ((json['evidence'] as List?) ?? [])
            .map((e) => EvidenceChunk.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static RankingBucket _bucketFrom(dynamic value) {
    switch (value) {
      case 'best':
        return RankingBucket.best;
      case 'strong':
        return RankingBucket.strong;
      case 'hidden_gem':
        return RankingBucket.hiddenGem;
      default:
        return RankingBucket.alternative;
    }
  }
}
