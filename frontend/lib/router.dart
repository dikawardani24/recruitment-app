import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'navigation/app_navigator.dart';
import 'navigation/app_route.dart';
import 'navigation/go_router_navigator.dart';
import 'screens/job_detail_screen.dart';
import 'screens/job_form_screen.dart';
import 'screens/job_list_screen.dart';
import 'screens/rankings_screen.dart';

/// Builds the app's [GoRouter]. Route patterns are derived from [AppRoute]
/// so that the enum stays the single source of truth for navigation.
class AppRouter {
  static GoRouter create() {
    return GoRouter(
      initialLocation: AppRoute.jobs.path,
      routes: [
        GoRoute(
          path: AppRoute.jobs.path,
          builder: (context, state) => const JobListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const JobFormScreen(),
            ),
            GoRoute(
              path: ':jobId',
              builder: (context, state) =>
                  JobDetailScreen(jobId: state.pathParameters['jobId']!),
              routes: [
                GoRoute(
                  path: 'rankings',
                  builder: (context, state) {
                    final data = state.extra as RankingsScreenData?;
                    return RankingsScreen(
                      jobId: data?.jobId ?? '',
                      jobTitle: data?.jobTitle ?? '',
                      source: data?.source ?? 'rules',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// The app's single [GoRouter] instance. Overridden in `main()` so the same
/// instance is shared by the widget tree and [navigatorProvider].
final goRouterProvider = Provider<GoRouter>(
  (ref) => throw UnimplementedError('goRouterProvider must be overridden'),
);

/// [AppNavigator] implementation exposed to the widget tree. Screens read
/// this provider and never touch go_router directly.
final navigatorProvider = Provider<AppNavigator>(
  (ref) => GoRouterNavigator(ref.watch(goRouterProvider)),
);
