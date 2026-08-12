import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import 'app_navigator.dart';
import 'app_route.dart';

/// [AppNavigator] backed by go_router. This is the only place where route
/// paths from [AppRoute] are translated into go_router calls.
class GoRouterNavigator implements AppNavigator {
  final GoRouter _router;

  const GoRouterNavigator(this._router);

  @override
  void goToJobs() => _router.go(AppRoute.jobs.path);

  @override
  void goToJobForm() => _router.push(AppRoute.jobForm.path);

  @override
  void goToSettings() => _router.push(AppRoute.settings.path);

  @override
  void goToSearchJobs() => _router.push(AppRoute.searchJobs.path);

  @override
  void goToSearchCandidates() => _router.push(AppRoute.searchCandidates.path);

  @override
  void goToSearch() => _router.push(AppRoute.search.path);

  @override
  void goToChat() => _router.push(AppRoute.chat.path);

  @override
  void goToApiKey() => _router.push(AppRoute.apiKey.path);

  @override
  void goToJobDetail(String jobId) =>
      _router.push(AppRoute.jobDetail.withJobId(jobId));

  @override
  void goToCandidateDetail(String jobId, CandidateResult candidate) => _router.push(
        AppRoute.candidateDetail.withCandidate(
          jobId,
          candidate.cvId ?? 'none',
        ),
        extra: candidate,
      );

  @override
  void goToRankings(RankingsScreenData data) => _router.push(
        AppRoute.rankings.withJobId(data.jobId),
        extra: data,
      );

  @override
  Future<bool> pushDeleteConfirm(DeleteConfirmArgs args) => _router
      .push<bool>(AppRoute.deleteConfirm.path, extra: args)
      .then((confirmed) => confirmed ?? false);

  @override
  Future<void> pushActionResult(ActionResultData data) =>
      _router.push(AppRoute.actionResult.path, extra: data);

  @override
  void pop() => _router.pop();
}
