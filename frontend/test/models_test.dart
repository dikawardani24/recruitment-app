import 'package:ai_ats/data/api/mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JobResponseMapper.fromJson', () {
    test('parses requirements', () {
      final job = JobResponseMapper.fromJson({
        'job_id': 'abc',
        'title': 'Backend Engineer',
        'description': 'Build things',
        'status': 'open',
        'created_at': '2026-01-01T00:00:00',
        'requirements': {
          'required_skills': ['Python', 'Docker'],
          'preferred_skills': ['Kubernetes'],
          'min_years': 5.0,
          'education': 'bsc',
          'certifications': ['AWS Certified'],
          'responsibilities': ['Build services'],
        },
      });
      expect(job.title, 'Backend Engineer');
      expect(job.requirements!.requiredSkills, ['Python', 'Docker']);
      expect(job.requirements!.minYears, 5.0);
      expect(job.requirements!.education, 'bsc');
    });

    test('handles missing requirements', () {
      final job = JobResponseMapper.fromJson({
        'job_id': 'abc',
        'title': 'Backend Engineer',
        'description': '',
        'status': 'open',
        'created_at': '2026-01-01T00:00:00',
      });
      expect(job.requirements, isNull);
    });
  });

  group('CandidateResponseMapper.fromJson', () {
    test('parses ranking payload', () {
      final result = CandidateResponseMapper.fromJson({
        'cv_id': '1',
        'file_name': 'john.txt',
        'status': 'ranked',
        'candidate_name': 'John Doe',
        'overall_score': 0.92,
        'bucket': 'strong_match',
        'recommendation': 'Strong match',
        'explanation': 'Matches most skills.',
        'strengths': ['Python', 'AWS'],
        'weaknesses': ['No Kubernetes'],
        'skill_gaps': ['Kubernetes'],
        'skills': ['Python', 'AWS'],
        'rank': 1,
      });
      expect(result.candidateName, 'John Doe');
      expect(result.overallScore, 0.92);
      expect(result.bucket, 'strong_match');
      expect(result.skillGaps, ['Kubernetes']);
      expect(result.rank, 1);
    });
  });

  group('JobPageResponseMapper.fromJson', () {
    test('parses envelope with meta', () {
      final page = JobPageResponseMapper.fromJson({
        'jobs': [
          {'job_id': 'abc', 'title': 'Backend Engineer', 'status': 'open'},
        ],
        'meta': {'page': 2, 'has_more': true},
      }, fallbackPage: 1, fallbackLimit: 20);
      expect(page.jobs, hasLength(1));
      expect(page.page, 2);
      expect(page.hasMore, isTrue);
    });
  });

  group('RankResponseMapper.fromJson', () {
    test('defaults source to rules', () {
      final rank = RankResponseMapper.fromJson({
        'results': [
          {'file_name': 'john.txt', 'status': 'ranked'},
        ],
      });
      expect(rank.source, 'rules');
      expect(rank.results, hasLength(1));
    });
  });
}
