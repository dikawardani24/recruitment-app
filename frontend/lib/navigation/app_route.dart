/// Navigation roots for the app.
///
/// Every navigation in the app is defined here and reached through the
/// [AppNavigator] interface — never by constructing routes or URLs inline.
enum AppRoute {
  jobs('/jobs'),
  jobForm('/jobs/new'),
  settings('/jobs/settings'),
  searchJobs('/jobs/search'),
  searchCandidates('/candidates/search'),
  jobDetail('/jobs/:jobId'),
  candidateDetail('/jobs/:jobId/candidate/:cvId'),
  rankings('/jobs/:jobId/rankings'),
  chat('/jobs/chat'),
  deleteConfirm('/jobs/delete-confirm'),
  actionResult('/jobs/action-result');

  const AppRoute(this.path);

  /// Route path pattern, using `:param` placeholders.
  final String path;

  /// Path with the `:jobId` placeholder filled in.
  String withJobId(String jobId) => path.replaceFirst(':jobId', jobId);

  /// Path with both placeholders filled in.
  String withCandidate(String jobId, String cvId) =>
      candidateDetail.path.replaceFirst(':jobId', jobId).replaceFirst(':cvId', cvId);
}
