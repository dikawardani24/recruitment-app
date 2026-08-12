/// Navigation roots for the app.
///
/// Every navigation in the app is defined here and reached through the
/// [AppNavigator] interface — never by constructing routes or URLs inline.
enum AppRoute {
  searchCandidates('/candidates/search'),
  jobs('/jobs'),
  actionResult('/jobs/action-result'),
  chat('/jobs/chat'),
  deleteConfirm('/jobs/delete-confirm'),
  jobDetail('/jobs/:jobId'),
  candidateDetail('/jobs/:jobId/candidate/:cvId'),
  rankings('/jobs/:jobId/rankings'),
  jobForm('/jobs/new'),
  searchJobs('/jobs/search'),
  search('/search'),
  settings('/settings'),
  apiKey('/settings/api-key');

  const AppRoute(this.path);

  /// Route path pattern, using `:param` placeholders.
  final String path;

  /// Path with the `:jobId` placeholder filled in.
  String withJobId(String jobId) => path.replaceFirst(':jobId', jobId);

  /// Path with both placeholders filled in.
  String withCandidate(String jobId, String cvId) =>
      candidateDetail.path.replaceFirst(':jobId', jobId).replaceFirst(':cvId', cvId);
}
