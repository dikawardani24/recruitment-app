import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/features/ranking/domain/ranking_models.dart';

void main() {
  test('RankedCandidate parses API response', () {
    final json = <String, dynamic>{
      'candidate_id': 'abc',
      'candidate_name': 'Jane Doe',
      'bucket': 'hidden_gem',
      'overall_score': 0.71,
      'scores': {
        'skill_match': 0.9,
        'experience_match': 0.5,
        'education_match': 0.6,
        'certification_match': 0.4,
      },
      'explanation': 'Strong signals despite fewer years.',
      'evidence': [
        {
          'chunk_id': 'c-1',
          'section': 'projects',
          'score': 0.88,
          'text': 'openbank-sdk — 700 stars',
        },
      ],
    };

    final candidate = RankedCandidate.fromJson(json);
    expect(candidate.candidateName, 'Jane Doe');
    expect(candidate.bucket, RankingBucket.hiddenGem);
    expect(candidate.overallScore, closeTo(0.71, 0.001));
    expect(candidate.scores.skillMatch, closeTo(0.9, 0.001));
    expect(candidate.evidence, hasLength(1));
    expect(candidate.evidence.first.text, contains('openbank-sdk'));
  });
}
