import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'models.dart';
import 'navigation/app_navigator.dart';
import 'navigation/go_router_navigator.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

final jobsProvider = FutureProvider<List<Job>>((ref) {
  return ref.read(apiClientProvider).listJobs();
});

final jobProvider = FutureProvider.family<Job, String>((ref, jobId) {
  return ref.read(apiClientProvider).getJob(jobId);
});

final cvsProvider = FutureProvider.family<List<CandidateResult>, String>((ref, jobId) {
  return ref.read(apiClientProvider).listCvs(jobId);
});

final rankingsProvider = FutureProvider.family<List<CandidateResult>, String>((ref, jobId) {
  return ref.read(apiClientProvider).getRankings(jobId);
});

/// The app's single [GoRouter] instance. Overridden in `main()` so the same
/// instance is shared by the widget tree and [navigatorProvider].
final goRouterProvider = Provider<GoRouter>(
  (ref) => throw UnimplementedError('goRouterProvider must be overridden'),
);

/// [AppNavigator] implementation exposed to the widget tree. Screens and
/// controllers read this provider and never touch go_router directly.
final navigatorProvider = Provider<AppNavigator>(
  (ref) => GoRouterNavigator(ref.watch(goRouterProvider)),
);
