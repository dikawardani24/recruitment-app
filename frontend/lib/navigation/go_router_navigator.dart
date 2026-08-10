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
  void goToJobForm() => _router.go(AppRoute.jobForm.path);

  @override
  void goToSettings() => _router.go(AppRoute.settings.path);

  @override
  void goToSearchJobs() => _router.go(AppRoute.searchJobs.path);

  @override
  void goToJobDetail(String jobId) =>
      _router.go(AppRoute.jobDetail.withJobId(jobId));

  @override
  void goToCandidateDetail(String jobId, CandidateResult candidate) => _router.go(
        AppRoute.candidateDetail.withCandidate(
          jobId,
          candidate.cvId ?? 'none',
        ),
        extra: candidate,
      );

  @override
  void goToRankings(RankingsScreenData data) => _router.go(
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
