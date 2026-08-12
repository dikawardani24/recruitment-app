import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:go_router/go_router.dart';

import 'domain/models.dart';
import 'navigation/app_navigator.dart';
import 'navigation/app_route.dart';
import 'screens/action_result_screen.dart';
import 'screens/candidate_detail_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/delete_confirm_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/job_detail_screen.dart';
import 'screens/job_form_screen.dart';
import 'screens/job_list_screen.dart';
import 'screens/rankings_screen.dart';
import 'screens/search_candidate_screen.dart';
import 'screens/search_job_screen.dart';
import 'screens/unified_search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/api_key_screen.dart';

/// Builds the app's [GoRouter]. Route patterns are derived from [AppRoute]
/// so that the enum stays the single source of truth for navigation.
class AppRouter {
  /// Returns [childPath] relative to [parentPath], e.g. given
  /// `/jobs/:jobId` and `/jobs/:jobId/rankings` it returns `rankings`.
  static String childPath(String parentPath, String childPath) {
    if (!childPath.startsWith(parentPath)) return childPath;
    return childPath.substring(parentPath.length).replaceFirst(RegExp(r'^/+'), '');
  }

  static GoRouter create({String? initialLocation}) {
    return GoRouter(
      navigatorKey: ChuckerFlutter.navigatorKey,
      initialLocation: initialLocation ?? AppRoute.jobs.path,
      routes: [
        GoRoute(
          path: AppRoute.intro.path,
          builder: (context, state) => const IntroScreen(),
        ),
        GoRoute(
          path: AppRoute.jobs.path,
          builder: (context, state) => const JobListScreen(),
          routes: [
            GoRoute(
              path: childPath(AppRoute.jobs.path, AppRoute.jobForm.path),
              builder: (context, state) => const JobFormScreen(),
            ),
            GoRoute(
              path: childPath(AppRoute.jobs.path, AppRoute.searchJobs.path),
              builder: (context, state) => const SearchJobScreen(),
            ),
            GoRoute(
              path: childPath(AppRoute.jobs.path, AppRoute.chat.path),
              builder: (context, state) => const ChatScreen(),
            ),
            GoRoute(
              path: childPath(AppRoute.jobs.path, AppRoute.deleteConfirm.path),
              builder: (context, state) => DeleteConfirmScreen(
                args: state.extra as DeleteConfirmArgs? ??
                    const DeleteConfirmArgs(
                      data: DeleteConfirmData(title: '', message: ''),
                    ),
              ),
            ),
            GoRoute(
              path: childPath(AppRoute.jobs.path, AppRoute.actionResult.path),
              builder: (context, state) => ActionResultScreen(
                data: state.extra as ActionResultData? ??
                    const ActionResultData(success: true, title: ''),
              ),
            ),
            GoRoute(
              path: childPath(AppRoute.jobs.path, AppRoute.jobDetail.path),
              builder: (context, state) =>
                  JobDetailScreen(jobId: state.pathParameters['jobId']!),
              routes: [
                GoRoute(
                  path: childPath(
                    AppRoute.jobDetail.path,
                    AppRoute.candidateDetail.path,
                  ),
                  builder: (context, state) => CandidateDetailScreen(
                    jobId: state.pathParameters['jobId']!,
                    cvId: state.pathParameters['cvId']!,
                    initial: state.extra as CandidateResult?,
                  ),
                ),
                GoRoute(
                  path: childPath(AppRoute.jobDetail.path, AppRoute.rankings.path),
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
        GoRoute(
          path: AppRoute.searchCandidates.path,
          builder: (context, state) => const SearchCandidateScreen(),
        ),
        GoRoute(
          path: AppRoute.search.path,
          builder: (context, state) => const UnifiedSearchScreen(),
        ),
        GoRoute(
          path: AppRoute.settings.path,
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: childPath(AppRoute.settings.path, AppRoute.apiKey.path),
              builder: (context, state) => const ApiKeyScreen(),
            ),
          ],
        ),
      ],
    );
  }
}

