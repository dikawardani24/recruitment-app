class UploadState {
  final bool uploading;
  final bool completed;
  final int totalFiles;
  final int uploadedFiles;
  final int failedFiles;
  final int currentBatch;
  final int totalBatches;
  final double batchProgress;
  final String? error;
  final String? importId;

  const UploadState({
    this.uploading = false,
    this.completed = false,
    this.totalFiles = 0,
    this.uploadedFiles = 0,
    this.failedFiles = 0,
    this.currentBatch = 0,
    this.totalBatches = 0,
    this.batchProgress = 0,
    this.error,
    this.importId,
  });

  double get fraction => totalFiles == 0 ? 0 : uploadedFiles / totalFiles;

  bool get hasFailures => failedFiles > 0;

  UploadState copyWith({
    bool? uploading,
    bool? completed,
    int? totalFiles,
    int? uploadedFiles,
    int? failedFiles,
    int? currentBatch,
    int? totalBatches,
    double? batchProgress,
    String? error,
    String? importId,
  }) {
    return UploadState(
      uploading: uploading ?? this.uploading,
      completed: completed ?? this.completed,
      totalFiles: totalFiles ?? this.totalFiles,
      uploadedFiles: uploadedFiles ?? this.uploadedFiles,
      failedFiles: failedFiles ?? this.failedFiles,
      currentBatch: currentBatch ?? this.currentBatch,
      totalBatches: totalBatches ?? this.totalBatches,
      batchProgress: batchProgress ?? this.batchProgress,
      error: error ?? this.error,
      importId: importId ?? this.importId,
    );
  }
}
