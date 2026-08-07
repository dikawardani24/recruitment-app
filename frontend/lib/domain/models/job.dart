import 'job_requirements.dart';

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
}
