import 'package:ai_ats/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Job.fromJson', () {
    test('parses requirements', () {
      final job = Job.fromJson({
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
      final job = Job.fromJson({
        'job_id': 'abc',
        'title': 'Backend Engineer',
        'description': '',
        'status': 'open',
        'created_at': '2026-01-01T00:00:00',
      });
      expect(job.requirements, isNull);
    });
  });

  group('CandidateResult.fromJson', () {
    test('parses ranking payload', () {
      final result = CandidateResult.fromJson({
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
}
