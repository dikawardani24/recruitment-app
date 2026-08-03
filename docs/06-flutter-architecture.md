# 06 — Flutter Application Architecture

## 1. Overview

Flutter client follows **feature-first Clean Architecture** with:
- **BLoC/Cubit** for state management (predictable, testable, async-friendly).
- **go_router** for navigation + auth guards.
- **get_it** (service locator) as composition root — mirrors backend DI.
- **dio** for networking with auth + retry interceptors.
- Material 3 theming with `ColorScheme.fromSeed`.

```
Feature structure (per feature):  data → domain → presentation
```

## 2. Layer Rules

```
┌──────────────────────────────────────────────────────────────┐
│                        PRESENTATION                          │  Widgets, BLoC/Cubit,
│  screens  ·  widgets  ·  state (bloc/cubit)  ·  routes        │  state, navigation
├──────────────────────────────────────────────────────────────┤
│                           DOMAIN                             │  Entities, repository
│  entities  ·  repository interfaces  ·  use cases (optional)  │  interfaces, models
├──────────────────────────────────────────────────────────────┤
│                            DATA                              │  Implements repo
│  datasources (api)  ·  repository impl  ·  DTO mappers        │  interfaces
└──────────────────────────────────────────────────────────────┘
```

- **Presentation depends on domain interfaces only** — swapped in tests with fakes.
- **Data** contains all third-party/API concerns (`ApiClient`).
- **core/** holds shared infrastructure (network, storage, theme) — feature-agnostic.

## 3. Dependency Graph & Composition Root

`app/di.dart` wires everything at startup:

```dart
Future<void> initDi(Environment env) async {
  final dio = ApiClient(env.apiBaseUrl)..addInterceptors(authInterceptor());
  getIt
    ..registerLazySingleton<ApiClient>(() => dio)
    ..registerLazySingleton<SecureStorage>(() => SecureStorage())
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(dio))
    ..registerLazySingleton<CandidateRepository>(() => CandidateRepositoryImpl(dio))
    ..registerLazySingleton<SearchRepository>(() => SearchRepositoryImpl(dio))
    ..registerLazySingleton<RankingRepository>(() => RankingRepositoryImpl(dio));
}
```

## 4. Navigation & Guards (go_router)

```dart
GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(path: '/login', builder: (_) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_) => const RegisterScreen()),
    ShellRoute(
      builder: (_, child) => AppShell(child: child),        // nav rail + bottom bar
      routes: [
        GoRoute(path: '/dashboard', builder: (_) => const DashboardScreen()),
        GoRoute(path: '/search',   builder: (_) => const SearchScreen()),
        GoRoute(path: '/candidates/:id', builder: (_, s) => CandidateProfileScreen(id: s.pathParameters['id']!)),
        GoRoute(path: '/jobs',     builder: (_) => const JobListScreen()),
        GoRoute(path: '/compare',  builder: (_) => const CompareScreen()),
      ],
    ),
  ],
  redirect: (context, state) => authGuard(state),           // unauthenticated → /login
)
```

## 5. State Management Pattern (Cubit Example)

```dart
class SearchCubit extends Cubit<SearchState> {
  final SearchRepository _repo;
  SearchCubit(this._repo) : super(SearchIdle());

  Future<void> search(String query, {SearchFilters? filters}) async {
    emit(SearchLoading());
    try {
      final result = await _repo.query(query, filters: filters);
      emit(SearchLoaded(result));
    } on ApiException catch (e) {
      emit(SearchError(e.userMessage));
    }
  }
}
```

States are sealed classes: `SearchIdle | SearchLoading | SearchLoaded | SearchError`. The widget layer is pure — it renders state, no business logic.

## 6. Key Screens

| Screen | Feature | Notes |
|--------|---------|-------|
| Login / Register | auth | JWT stored in secure storage |
| Resume Upload | resume_upload | File picker → upload → **polls** resume status (progress stepper QUEUED→INDEXED), error retry |
| Candidate Profile | candidate_profile | Structured sections; **resume viewer** loads original PDF (webview/pdf_view) |
| Search | search | NL query bar, filters chips, results list with buckets |
| Ranking | ranking | Bucket tabs (Best / Strong / Hidden Gem / Alternative), score gauges, **explanation sheet**, **evidence drawer** with chunk text |
| Compare | compare | Select candidates → comparison table + AI summary panel |
| Jobs | jobs | JD CRUD + "Rank for this job" |
| Dashboard | dashboard | Metrics: candidates by status, pipeline health, recent rankings |

## 7. Cross-Feature UX for AI Evidence

To keep the recruiter trust-worthy, ranking screens always expose:
- **Explanation card** (why this candidate ranked here).
- **Evidence drawer**: each strength/weakness links to the `chunk_id` + `original_text` returned by the API. Recruiter taps → sees the exact resume text the LLM used.

## 8. Offline & Error Strategy

| Concern | Approach |
|---------|----------|
| Token refresh | dio interceptor on 401 → refresh → retry queue |
| Retry | Exponential backoff for polling resume status |
| Network errors | `ApiException.userMessage` mapped to friendly copy |
| Caching | `local_cache` for dashboard metrics (short TTL) |

## 9. Testing

| Level | Scope |
|-------|-------|
| Unit | Cubits with fake repositories (verify state transitions) |
| Widget | Screens with `tester.pump` + fake DI (`getIt.reset()` then register fakes) |
| Integration | Golden tests for theme consistency; API contract tests using `Mocktail` |

## 10. Theme (Material 3)

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E8C)),
  useMaterial3: true,
  // surface containers for cards, tonal elevation, custom score-gauge widgets
)
```

Design tokens (spacing, radii, type scale) live in `app/theme/` and are reused across features so the AI evidence/ranking components stay visually consistent.
