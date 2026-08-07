import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/controllers/job_list_controller.dart';
import 'package:ai_ats/models.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/screens/job_list_screen.dart';
import 'package:ai_ats/widgets/shimmer.dart';

/// Notifier whose refresh stays pending until the test completes it, so the
/// shimmer can be asserted while reloading.
class _RefreshableNotifier extends JobListNotifier {
  _RefreshableNotifier(this._jobs);

  final List<Job> _jobs;
  Completer<JobListState>? pending;

  @override
  Future<JobListState> build() async {
    return JobListState(jobs: _jobs, page: 1, hasMore: false);
  }

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    pending = Completer<JobListState>();
    state = AsyncValue.data(await pending!.future);
  }
}

/// Notifier whose build stays pending until a [Completer] resolves, used to
/// keep the list in its initial loading state for tests.
class _PendingJobListNotifier extends JobListNotifier {
  _PendingJobListNotifier(this._completer);

  final Completer<JobListState> _completer;

  @override
  Future<JobListState> build() => _completer.future;
}

/// Notifier whose pages are provided in-memory so widget tests never hit the
/// real API client.
class _FakeJobListNotifier extends JobListNotifier {
  _FakeJobListNotifier(this._pages);

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
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncValue.data(await build());
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

/// Notifier whose job list can have jobs removed so a delete can be reflected
/// after the list is reloaded.
class _DeletableJobListNotifier extends JobListNotifier {
  _DeletableJobListNotifier(this._jobs);

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

/// Controller that records deletes and removes the job from the notifier,
/// mimicking a successful server-side delete followed by a refresh.
class _FakeJobListController extends JobListController {
  _FakeJobListController(super.ref, this._notifier, this.candidates);

  final _DeletableJobListNotifier _notifier;
  final List<CandidateResult> candidates;
  final deletedJobs = <String>[];

  @override
  Future<List<CandidateResult>> candidatesFor(String jobId) async =>
      candidates;

  @override
  Future<void> deleteJob(String jobId) async {
    deletedJobs.add(jobId);
    _notifier.removeById(jobId);
    await refresh();
  }
}

void main() {
  test('formatCreatedAt renders dd MMM yyyy h:mm am/pm', () {
    final formatted = formatCreatedAt('2026-08-06T14:05:00');
    expect(formatted, '06 Aug 2026 2:05 pm');
  });

  test('formatCreatedAt uses am for morning times', () {
    final formatted = formatCreatedAt('2026-01-01T09:30:00');
    expect(formatted, '01 Jan 2026 9:30 am');
  });

  test('formatCreatedAt handles noon and midnight', () {
    expect(formatCreatedAt('2026-03-15T12:00:00'), contains('12:00 pm'));
    expect(formatCreatedAt('2026-03-15T00:00:00'), contains('12:00 am'));
  });

  test('formatCreatedAt returns empty for missing input', () {
    expect(formatCreatedAt(null), '');
    expect(formatCreatedAt('not-a-date'), '');
  });

  testWidgets('shows shimmer skeletons while the initial list loads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final completer = Completer<JobListState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsProvider.overrideWith(
            () => _PendingJobListNotifier(completer),
          ),
        ],
        child: const MaterialApp(home: JobListScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsNWidgets(5));

    completer.complete(JobListState(jobs: [], hasMore: false));
    await tester.pump();

    expect(find.byType(Shimmer), findsNothing);
  });

  testWidgets('pull to refresh shows the shimmer while reloading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _RefreshableNotifier([_job('j1', 'Backend Engineer')]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jobsProvider.overrideWith(() => notifier)],
        child: const MaterialApp(home: JobListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Backend Engineer'), findsOneWidget);
    expect(find.byType(Shimmer), findsNothing);

    await tester.fling(
      find.text('Backend Engineer'),
      const Offset(0, 600),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(Shimmer), findsNWidgets(5));
    expect(find.text('Backend Engineer'), findsNothing);

    notifier.pending?.complete(
      JobListState(jobs: [_job('j1', 'Backend Engineer')], hasMore: false),
    );
    await tester.pump();

    expect(find.text('Backend Engineer'), findsOneWidget);
    expect(find.byType(Shimmer), findsNothing);
  });

  testWidgets('job cards show candidate counts and header totals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final jobs = [
      _job('j1', 'Backend Engineer', candidates: 12),
      _job('j2', 'Mobile Developer', candidates: 3),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsProvider.overrideWith(() => _FakeJobListNotifier([jobs])),
        ],
        child: const MaterialApp(home: JobListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('12 candidates'), findsOneWidget);
    expect(find.text('3 candidates'), findsOneWidget);
    expect(find.text('15 candidates · 2 jobs'), findsOneWidget);
    expect(find.text('No more jobs'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('scrolling to the bottom loads the next page', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final page1 = List.generate(
      20,
      (i) => _job('p1-$i', 'Job $i'),
    );
    final page2 = [_job('p2', 'Job 20')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsProvider.overrideWith(
            () => _FakeJobListNotifier([page1, page2]),
          ),
        ],
        child: const MaterialApp(home: JobListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Job 20'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.text('Job 20'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump();

    expect(find.text('No more jobs'), findsOneWidget);
  });

  testWidgets('shows a spinner while the next page is loading', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final page1 = List.generate(
      20,
      (i) => _job('p1-$i', 'Job $i'),
    );
    final page2 = List.generate(20, (i) => _job('p2-$i', 'Job ${i + 20}'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsProvider.overrideWith(
            () => _FakeJobListNotifier([page1, page2]),
          ),
        ],
        child: const MaterialApp(home: JobListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump();
    await tester.pump();

    // isLoadingMore was set synchronously; the delayed page resolves on the
    // next timer tick.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsWidgets,
    );

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump();

    expect(find.text('Job 39'), findsOneWidget);
    expect(find.text('No more jobs'), findsOneWidget);
  });

  group('job deletion', () {
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

    Future<_FakeJobListController> pumpList(
      WidgetTester tester, {
      required _DeletableJobListNotifier notifier,
      required List<CandidateResult> candidates,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late final _FakeJobListController controller;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsProvider.overrideWith(() => notifier),
            jobListControllerProvider.overrideWith(
              (ref) => controller =
                  _FakeJobListController(ref, notifier, candidates),
            ),
          ],
          child: const MaterialApp(home: JobListScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      return controller;
    }

    testWidgets('swipe reveals confirmation with affected candidates', (
      tester,
    ) async {
      final notifier = _DeletableJobListNotifier([
        _job('j1', 'Backend Engineer', candidates: 1),
        _job('j2', 'Mobile Dev', candidates: 0),
      ]);
      await pumpList(tester, notifier: notifier, candidates: [
        candidate('c1', 'John Doe'),
      ]);

      await tester.fling(
        find.text('Backend Engineer'),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete this job?'), findsOneWidget);
      expect(
        find.text('This job and its 1 candidate will be permanently removed.'),
        findsOneWidget,
      );
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Delete job'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancelling restores the card and deletes nothing', (
      tester,
    ) async {
      final notifier = _DeletableJobListNotifier([
        _job('j1', 'Backend Engineer', candidates: 1),
        _job('j2', 'Mobile Dev', candidates: 0),
      ]);
      final controller = await pumpList(tester, notifier: notifier, candidates: [
        candidate('c1', 'John Doe'),
      ]);

      await tester.fling(
        find.text('Backend Engineer'),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Backend Engineer'), findsOneWidget);
      expect(controller.deletedJobs, isEmpty);
    });

    testWidgets('confirming deletes the job and refreshes the list', (
      tester,
    ) async {
      final notifier = _DeletableJobListNotifier([
        _job('j1', 'Backend Engineer', candidates: 1),
        _job('j2', 'Mobile Dev', candidates: 0),
      ]);
      final controller = await pumpList(tester, notifier: notifier, candidates: [
        candidate('c1', 'John Doe'),
      ]);

      await tester.fling(
        find.text('Backend Engineer'),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete job'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.deletedJobs, ['j1']);
      expect(find.text('Backend Engineer'), findsNothing);
      expect(find.text('Mobile Dev'), findsOneWidget);
      expect(find.text('Job deleted'), findsOneWidget);
    });
  });
}
