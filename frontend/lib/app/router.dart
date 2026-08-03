import 'package:go_router/go_router.dart';

import '../features/search/presentation/search_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/search',
  routes: [
    GoRoute(path: '/search', builder: (_, state) => const SearchScreen()),
  ],
);
