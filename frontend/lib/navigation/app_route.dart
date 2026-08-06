/// Navigation roots for the app.
///
/// Every navigation in the app is defined here and reached through the
/// [AppNavigator] interface — never by constructing routes or URLs inline.
enum AppRoute {
  jobs('/jobs'),
  jobForm('/jobs/new'),
  jobDetail('/jobs/:jobId'),
  rankings('/jobs/:jobId/rankings');

  const AppRoute(this.path);

  /// Route path pattern, using `:param` placeholders.
  final String path;

  /// Path with the `:jobId` placeholder filled in.
  String withJobId(String jobId) => path.replaceFirst(':jobId', jobId);
}
