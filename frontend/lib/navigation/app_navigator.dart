/// Data passed to the rankings screen when navigating to it.
class RankingsScreenData {
  final String jobId;
  final String jobTitle;
  final String source;

  const RankingsScreenData({
    required this.jobId,
    required this.jobTitle,
    required this.source,
  });
}

/// Defines every navigation that can be performed in the app.
///
/// Screens depend on this interface instead of go_router directly. The
/// concrete implementation decides how to translate a call into an actual
/// route change.
abstract class AppNavigator {
  void goToJobs();

  void goToJobForm();

  void goToJobDetail(String jobId);

  void goToRankings(RankingsScreenData data);

  void pop();
}
