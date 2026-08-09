class ImportResponse {
  final String importId;
  final String jobId;
  final String status;
  final int totalFiles;
  final int batchFiles;

  const ImportResponse({
    required this.importId,
    required this.jobId,
    required this.status,
    required this.totalFiles,
    required this.batchFiles,
  });
}

class ImportStatus {
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

  const ImportStatus({
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

  bool get isTerminal =>
      status == 'completed' ||
      status == 'partially_failed' ||
      status == 'failed';
}
