import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/controllers/job_list_controller.dart';
import 'package:ai_ats/domain/models.dart';
import 'package:ai_ats/navigation/app_navigator.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/screens/action_result_screen.dart';
import 'package:ai_ats/screens/delete_confirm_screen.dart';
import 'package:ai_ats/screens/search_job_screen.dart';
import 'package:ai_ats/widgets/shimmer.dart';

class _FakeNavigator implements AppNavigator {
  final navigatorKey = GlobalKey<NavigatorState>();
  final openedJobIds = <String>[];
  var popCount = 0;

  @override
  void goToJobs() {}

  @override
  void goToJobForm() {}

  @override
  void goToSettings() {}

  @override
  void goToSearchJobs() {}

  @override
  void goToSearchCandidates() {}

  @override
  void goToSearch() {}

  @override
  void goToChat() {}

  @override
  void goToApiKey() {}

  @override
  void goToHelp() {}

  @override
  void goToJobDetail(String jobId) => openedJobIds.add(jobId);

  @override
  void goToCandidateDetail(String jobId, CandidateResult candidate) {}

  @override
  void goToRankings(RankingsScreenData data) {}

  @override
  Future<bool> pushDeleteConfirm(DeleteConfirmArgs args) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;
    return await navigator.push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => DeleteConfirmScreen(args: args),
          ),
        ) ??
        false;
  }

  @override
  Future<void> pushActionResult(ActionResultData data) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActionResultScreen(data: data),
      ),
    );
  }

  @override
  void pop() => popCount++;
}

/// Notifier whose build stays pending until a [Completer] resolves, used to
/// assert the shimmer while the initial search loads.
class _PendingSearchNotifier extends SearchJobNotifier {
  _PendingSearchNotifier(super.keyword, this._completer);

  final Completer<JobListState> _completer;

  @override
  Future<JobListState> build() => _completer.future;
}

/// Notifier that answers each keyword with a fixed result list so widget tests
/// never hit the real API client.
class _FakeSearchNotifier extends SearchJobNotifier {
  _FakeSearchNotifier(super.keyword, this._results);

  final Map<String, List<Job>> _results;

  @override
  Future<JobListState> build() async {
    return JobListState(
      jobs: _results[keyword] ?? const [],
      page: 1,
      hasMore: false,
    );
  }

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncValue.data(await build());
  }
}

/// Notifier whose pages are provided in-memory for the pagination test.
class _PaginatedSearchNotifier extends SearchJobNotifier {
  _PaginatedSearchNotifier(super.keyword, this._pages);

  final List<List<Job>> _pages;
  int _loaded = 0;

  @override
  Future<JobListState> build() async {
    _loaded = 1;
    return JobListState(
      jobs: _pages.first,
      page: 1,
      hasMore: _pages.length > 1,
    );
  }

  @override
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final nextJobs = _loaded < _pages.length ? _pages[_loaded] : const <Job>[];
    _loaded++;
    state = AsyncValue.data(
      current.copyWith(
        jobs: [...current.jobs, ...nextJobs],
        page: current.page + 1,
        hasMore: _loaded < _pages.length,
        isLoadingMore: false,
      ),
    );
  }

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncValue.data(await build());
  }
}

/// Notifier whose result list can lose jobs so a delete is reflected after the
/// search reloads.
class _DeletableSearchNotifier extends SearchJobNotifier {
  _DeletableSearchNotifier(super.keyword, this._jobs);

  final List<Job> _jobs;

  @override
  Future<JobListState> build() async {
    return JobListState(jobs: List.of(_jobs), page: 1, hasMore: false);
  }

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncValue.data(await build());
  }

  void removeById(String jobId) {
    _jobs.removeWhere((j) => j.id == jobId);
  }
}

/// Controller that records deletes and removes the job from the search notifier,
/// mimicking a successful server-side delete followed by a refresh.
class _FakeSearchJobListController extends JobListController {
  _FakeSearchJobListController(super.ref, this._notifier, this.candidates);

  final _DeletableSearchNotifier _notifier;
  final List<CandidateResult> candidates;
  final deletedJobs = <String>[];

  @override
  Future<List<CandidateResult>> candidatesFor(String jobId) async => candidates;

  @override
  Future<void> removeJob(String jobId) async {
    deletedJobs.add(jobId);
    _notifier.removeById(jobId);
    await refresh();
  }
}

Job _job(String id, String title, {int candidates = 0}) {
  return Job(
    id: id,
    title: title,
    description: '',
    status: 'open',
    createdAt: '2026-08-06T14:05:00',
    candidateCount: candidates,
  );
}

void main() {
  testWidgets('shows shimmer while the initial search loads', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final completer = Completer<JobListState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _PendingSearchNotifier(kw, completer),
          ),
        ],
        child: const MaterialApp(home: SearchJobScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsNWidgets(5));

    completer.complete(
      JobListState(jobs: [_job('j1', 'Backend Engineer')], hasMore: false),
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsNothing);
    expect(find.text('Backend Engineer'), findsOneWidget);
  });

  testWidgets('shows all jobs while the keyword is empty', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final results = {
      '': [_job('j1', 'Backend Engineer'), _job('j2', 'Mobile Developer')],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
        ],
        child: const MaterialApp(home: SearchJobScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Backend Engineer'), findsOneWidget);
    expect(find.text('Mobile Developer'), findsOneWidget);
  });

  testWidgets('pressing enter searches and replaces the results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final results = {
      '': [_job('j1', 'Backend Engineer')],
      'flutter': [_job('j2', 'Flutter Developer')],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
        ],
        child: const MaterialApp(home: SearchJobScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Backend Engineer'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();

    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.text('Backend Engineer'), findsNothing);
  });

  testWidgets('searching after a pause triggers when the user stops typing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final results = {
      '': [_job('j1', 'Backend Engineer')],
      'flutter': [_job('j2', 'Flutter Developer')],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
        ],
        child: const MaterialApp(home: SearchJobScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump();

    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.text('Backend Engineer'), findsNothing);
  });

  testWidgets('clearing the keyword shows all data again', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final results = {
      '': [_job('j1', 'Backend Engineer')],
      'flutter': [_job('j2', 'Flutter Developer')],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
        ],
        child: const MaterialApp(home: SearchJobScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump();
    expect(find.text('Flutter Developer'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Backend Engineer'), findsOneWidget);
    expect(find.text('Flutter Developer'), findsNothing);
  });

  testWidgets('shows a not-found view when there are no matches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final results = {
      '': [_job('j1', 'Backend Engineer')],
      'zzz': const <Job>[],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
        ],
        child: const MaterialApp(home: SearchJobScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();

    expect(find.text('No jobs found'), findsOneWidget);
    expect(find.text('No jobs match "zzz".'), findsOneWidget);
  });

  testWidgets('scrolling to the bottom loads the next page', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final page1 = List.generate(20, (i) => _job('p1-$i', 'Job $i'));
    final page2 = [_job('p2', 'Job 20')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _PaginatedSearchNotifier(kw, [page1, page2]),
          ),
        ],
        child: const MaterialApp(home: SearchJobScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Job 20'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.text('Job 20'), findsOneWidget);
  });

  testWidgets('tapping a result opens the job detail page', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigator = _FakeNavigator();
    final results = {
      '': [_job('j1', 'Backend Engineer')],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
          navigatorProvider.overrideWithValue(navigator),
        ],
        child: MaterialApp(
          navigatorKey: navigator.navigatorKey,
          home: const SearchJobScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Backend Engineer'));
    await tester.pump();

    expect(navigator.openedJobIds, ['j1']);
  });

  testWidgets('back button pops the navigator', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigator = _FakeNavigator();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, {
              '': [_job('j1', 'Backend Engineer')],
            }),
          ),
          navigatorProvider.overrideWithValue(navigator),
        ],
        child: MaterialApp(
          navigatorKey: navigator.navigatorKey,
          home: const SearchJobScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(navigator.popCount, 1);
  });

  testWidgets('search input uses an outlined border like the job form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, const {}),
          ),
        ],
        child: const MaterialApp(home: SearchJobScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    final decoration = textField.decoration!;
    expect(decoration.border, isA<OutlineInputBorder>());
  });

  testWidgets('shows recent searches when the keyword is empty', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final results = {
      '': [_job('j1', 'Backend Engineer')],
      'flutter': [_job('j2', 'Flutter Developer')],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
        ],
        child: const MaterialApp(home: SearchJobScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Recent searches'), findsNothing);

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();
    expect(find.text('Flutter Developer'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('flutter'), findsOneWidget);
  });

  testWidgets('tapping a recent search re-runs it', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final results = {
      '': [_job('j1', 'Backend Engineer')],
      'flutter': [_job('j2', 'Flutter Developer')],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchJobsProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
        ],
        child: const MaterialApp(home: SearchJobScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('flutter'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.text('Backend Engineer'), findsNothing);
  });

  group('deletion', () {
    CandidateResult candidate(String id, String name) {
      return CandidateResult(
        cvId: id,
        fileName: '$id.pdf',
        candidateName: name,
        status: 'ranked',
        overallScore: 0.9,
        bucket: 'strong_match',
      );
    }

    Future<_FakeSearchJobListController> pumpSearch(
      WidgetTester tester, {
      required _DeletableSearchNotifier notifier,
      required List<CandidateResult> candidates,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final navigator = _FakeNavigator();
      late final _FakeSearchJobListController controller;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchJobsProvider.overrideWith2((kw) => notifier),
            jobListControllerProvider.overrideWith(
              (ref) => controller = _FakeSearchJobListController(
                ref,
                notifier,
                candidates,
              ),
            ),
            navigatorProvider.overrideWithValue(navigator),
          ],
          child: MaterialApp(
            navigatorKey: navigator.navigatorKey,
            home: const SearchJobScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return controller;
    }

    testWidgets('swiping a result deletes the job and refreshes the list', (
      tester,
    ) async {
      final notifier = _DeletableSearchNotifier('', [
        _job('j1', 'Backend Engineer', candidates: 1),
        _job('j2', 'Mobile Dev', candidates: 0),
      ]);
      final controller = await pumpSearch(
        tester,
        notifier: notifier,
        candidates: [candidate('c1', 'John Doe')],
      );

      await tester.fling(
        find.text('Backend Engineer'),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete this job?'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(controller.deletedJobs, ['j1']);
      expect(find.text('Job deleted'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Backend Engineer'), findsNothing);
      expect(find.text('Mobile Dev'), findsOneWidget);
    });
  });
}
