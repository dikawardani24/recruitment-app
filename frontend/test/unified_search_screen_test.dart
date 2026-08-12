import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/domain/models.dart';
import 'package:ai_ats/navigation/app_navigator.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/screens/unified_search_screen.dart';

class _FakeNavigator implements AppNavigator {
  final navigatorKey = GlobalKey<NavigatorState>();
  final openedJobIds = <String>[];
  final openedCandidates = <CandidateResult>[];
  var popCount = 0;

  @override void goToJobs() {}
  @override void goToJobForm() {}
  @override void goToSettings() {}
  @override void goToSearchJobs() {}
  @override void goToSearchCandidates() {}
  @override void goToSearch() {}
  @override void goToChat() {}

  @override
  void goToApiKey() {}
  @override void goToJobDetail(String jobId) => openedJobIds.add(jobId);
  @override void goToCandidateDetail(String jobId, CandidateResult candidate) =>
      openedCandidates.add(candidate);
  @override void goToRankings(RankingsScreenData data) {}
  @override Future<bool> pushDeleteConfirm(DeleteConfirmArgs args) async => false;
  @override Future<void> pushActionResult(ActionResultData data) async {}
  @override void pop() => popCount++;
}

class _FakeUnifiedSearchNotifier extends UnifiedSearchNotifier {
  _FakeUnifiedSearchNotifier(super.keyword, this._results);
  final Map<String, UnifiedSearchResult> _results;

  @override
  Future<UnifiedSearchResult> build() async {
    return _results[keyword] ?? UnifiedSearchResult(
      keyword: keyword,
      jobs: [],
      jobsHasMore: false,
      candidates: [],
      candidatesHasMore: false,
    );
  }

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncValue.data(await build());
  }
}

Job _job(String id, String title) => Job(
  id: id, title: title, description: '', status: 'open',
  createdAt: '2026-08-12T00:00:00', candidateCount: 0,
);

CandidateResult _candidate(String id, String name) => CandidateResult(
  cvId: id, fileName: '$id.pdf', status: 'completed', candidateName: name,
);

void main() {
  testWidgets('shows empty state when keyword is empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unifiedSearchProvider.overrideWith2((kw) => _FakeUnifiedSearchNotifier(kw, {})),
        ],
        child: const MaterialApp(home: UnifiedSearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search your workspace'), findsOneWidget);
    expect(find.text('Jobs'), findsNothing);
  });

  testWidgets('shows results for both jobs and candidates', (tester) async {
    final results = {
      'flutter': UnifiedSearchResult(
        keyword: 'flutter',
        jobs: [_job('j1', 'Flutter Dev')],
        jobsHasMore: false,
        candidates: [_candidate('c1', 'Jane Flutter')],
        candidatesHasMore: false,
      ),
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unifiedSearchProvider.overrideWith2((kw) => _FakeUnifiedSearchNotifier(kw, results)),
        ],
        child: const MaterialApp(home: UnifiedSearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Flutter Dev'), findsOneWidget);
    expect(find.text('Candidates'), findsOneWidget);
    expect(find.text('Jane Flutter'), findsOneWidget);
  });

  testWidgets('tapping a job result opens job detail', (tester) async {
    final navigator = _FakeNavigator();
    final results = {
      'test': UnifiedSearchResult(
        keyword: 'test',
        jobs: [_job('j1', 'Test Job')],
        jobsHasMore: false,
        candidates: [],
        candidatesHasMore: false,
      ),
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unifiedSearchProvider.overrideWith2((kw) => _FakeUnifiedSearchNotifier(kw, results)),
          navigatorProvider.overrideWithValue(navigator),
        ],
        child: MaterialApp(navigatorKey: navigator.navigatorKey, home: const UnifiedSearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'test');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Job'));
    expect(navigator.openedJobIds, ['j1']);
  });
}
