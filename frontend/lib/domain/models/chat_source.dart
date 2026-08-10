/// A retrieved evidence chunk the copilot cited in its answer.
class ChatSource {
  final String entityType; // 'job' | 'candidate'
  final String entityId;
  final String? jobId;
  final String name;
  final String section;
  final double score;

  const ChatSource({
    required this.entityType,
    required this.entityId,
    this.jobId,
    required this.name,
    required this.section,
    required this.score,
  });

  String get label => entityType == 'job' ? 'Job' : 'Candidate';
}
