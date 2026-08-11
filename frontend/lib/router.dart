import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:go_router/go_router.dart';

import 'domain/models.dart';
import 'navigation/app_navigator.dart';
import 'navigation/app_route.dart';
import 'screens/action_result_screen.dart';
import 'screens/candidate_detail_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/delete_confirm_screen.dart';
import 'screens/job_detail_screen.dart';
import 'screens/job_form_screen.dart';
import 'screens/job_list_screen.dart';
import 'screens/rankings_screen.dart';
import 'screens/search_job_screen.dart';
import 'screens/settings_screen.dart';

/// Builds the app's [GoRouter]. Route patterns are derived from [AppRoute]
/// so that the enum stays the single source of truth for navigation.
class AppRouter {
  static GoRouter create() {
    return GoRouter(
      navigatorKey: ChuckerFlutter.navigatorKey,
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
              path: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: 'search',
              builder: (context, state) => const SearchJobScreen(),
            ),
            GoRoute(
              path: 'chat',
              builder: (context, state) => const ChatScreen(),
            ),
            GoRoute(
              path: 'delete-confirm',
              builder: (context, state) => DeleteConfirmScreen(
                args: state.extra as DeleteConfirmArgs? ??
                    const DeleteConfirmArgs(
                      data: DeleteConfirmData(title: '', message: ''),
                    ),
              ),
            ),
            GoRoute(
              path: 'action-result',
              builder: (context, state) => ActionResultScreen(
                data: state.extra as ActionResultData? ??
                    const ActionResultData(success: true, title: ''),
              ),
            ),
            GoRoute(
              path: ':jobId',
              builder: (context, state) =>
                  JobDetailScreen(jobId: state.pathParameters['jobId']!),
              routes: [
                GoRoute(
                  path: 'candidate/:cvId',
                  builder: (context, state) => CandidateDetailScreen(
                    jobId: state.pathParameters['jobId']!,
                    cvId: state.pathParameters['cvId']!,
                    initial: state.extra as CandidateResult?,
                  ),
                ),
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

