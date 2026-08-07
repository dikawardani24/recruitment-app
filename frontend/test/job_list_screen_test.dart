import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/models.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/screens/job_list_screen.dart';

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
}
