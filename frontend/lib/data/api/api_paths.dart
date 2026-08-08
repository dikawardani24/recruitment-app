class ApiPaths {
  ApiPaths._();

  static const String jobs = '/jobs';

  static String job(String jobId) => '/jobs/$jobId';

  static String cvs(String jobId) => '/jobs/$jobId/cvs';

  static String cv(String jobId, String cvId) => '/jobs/$jobId/cvs/$cvId';

  static String candidateImport(String jobId) =>
      '/jobs/$jobId/candidates/import';

  static String importStatus(String jobId, String importId) =>
      '/jobs/$jobId/imports/$importId';

  static String rank(String jobId) => '/jobs/$jobId/rank';

  static String cvRank(String jobId, String cvId) => '/jobs/$jobId/cvs/$cvId/rank';

  static String rankings(String jobId) => '/jobs/$jobId/rankings';
}
