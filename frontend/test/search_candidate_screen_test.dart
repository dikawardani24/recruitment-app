import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/controllers/deleteConfirm/delete_confirm_controller.dart';
import 'package:ai_ats/controllers/jobDetail/job_detail_controller.dart';
import 'package:ai_ats/domain/models.dart';
import 'package:ai_ats/navigation/app_navigator.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/screens/action_result_screen.dart';
import 'package:ai_ats/screens/delete_confirm_screen.dart';
import 'package:ai_ats/screens/search_candidate_screen.dart';
import 'package:ai_ats/widgets/shimmer.dart';

class _FakeNavigator implements AppNavigator {
  final navigatorKey = GlobalKey<NavigatorState>();
  final openedCandidates = <CandidateResult>[];
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
  void goToJobDetail(String jobId) {}
  @override
  void goToCandidateDetail(String jobId, CandidateResult candidate) =>
      openedCandidates.add(candidate);
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

class _PendingSearchNotifier extends CandidateSearchNotifier {
  _PendingSearchNotifier(super.keyword, this._completer);
  final Completer<CandidateListState> _completer;
  @override
  Future<CandidateListState> build() => _completer.future;
}

class _FakeSearchNotifier extends CandidateSearchNotifier {
  _FakeSearchNotifier(super.keyword, this._results);
  final Map<String, List<CandidateResult>> _results;
  @override
  Future<CandidateListState> build() async {
    return CandidateListState(
      candidates: _results[keyword] ?? const [],
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

class _PaginatedSearchNotifier extends CandidateSearchNotifier {
  _PaginatedSearchNotifier(super.keyword, this._pages);
  final List<List<CandidateResult>> _pages;
  int _loaded = 0;
  @override
  Future<CandidateListState> build() async {
    _loaded = 1;
    return CandidateListState(
      candidates: _pages.first,
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
    final nextCvs = _loaded < _pages.length ? _pages[_loaded] : const <CandidateResult>[];
    _loaded++;
    state = AsyncValue.data(
      current.copyWith(
        candidates: [...current.candidates, ...nextCvs],
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

class _DeletableSearchNotifier extends CandidateSearchNotifier {
  _DeletableSearchNotifier(super.keyword, this._candidates);
  final List<CandidateResult> _candidates;
  @override
  Future<CandidateListState> build() async {
    return CandidateListState(candidates: List.of(_candidates), page: 1, hasMore: false);
  }

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncValue.data(await build());
  }

  void removeById(String cvId) {
    _candidates.removeWhere((c) => c.cvId == cvId);
  }
}

class _FakeJobDetailController extends JobDetailController {
  _FakeJobDetailController(this.ref, this._notifier) : super(ref);
  final Ref ref;
  final _DeletableSearchNotifier _notifier;
  final deletedCvIds = <String>[];

  @override
  Future<bool> deleteCv(String jobId, CandidateResult cv) async {
    final cvId = cv.cvId;
    if (cvId == null) return false;

    final deleteFlow = ref.read(deleteConfirmControllerProvider.notifier);
    deleteFlow.prepare(
      onConfirm: () async {
        deletedCvIds.add(cvId);
        _notifier.removeById(cvId);
      },
      successResult: const ActionResultData(
        success: true,
        title: 'Candidate deleted',
      ),
    );

    return ref.read(navigatorProvider).pushDeleteConfirm(
      DeleteConfirmArgs(
        data: DeleteConfirmData(
          title: 'Delete this candidate?',
          message: 'Confirm?',
        ),
      ),
    );
  }
}

CandidateResult _candidate(String id, String name, {String? jobId}) {
  return CandidateResult(
    cvId: id,
    jobId: jobId ?? 'j1',
    fileName: '$id.pdf',
    candidateName: name,
    status: 'completed',
  );
}

void main() {
  testWidgets('shows shimmer while the initial search loads', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final completer = Completer<CandidateListState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchCandidatesProvider.overrideWith2(
            (kw) => _PendingSearchNotifier(kw, completer),
          ),
        ],
        child: const MaterialApp(home: SearchCandidateScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(Shimmer), findsNWidgets(5));
    completer.complete(
      CandidateListState(candidates: [_candidate('c1', 'John Doe')], hasMore: false),
    );
    await tester.pump();
    expect(find.byType(Shimmer), findsNothing);
    expect(find.text('John Doe'), findsOneWidget);
  });

  testWidgets('shows all results while the keyword is empty', (tester) async {
    final results = {
      '': [_candidate('c1', 'John Doe'), _candidate('c2', 'Jane Smith')],
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchCandidatesProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
        ],
        child: const MaterialApp(home: SearchCandidateScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsOneWidget);
  });

  testWidgets('pressing enter searches and replaces the results', (tester) async {
    final results = {
      '': [_candidate('c1', 'John Doe')],
      'jane': [_candidate('c2', 'Jane Smith')],
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchCandidatesProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
        ],
        child: const MaterialApp(home: SearchCandidateScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jane');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('John Doe'), findsNothing);
  });

  testWidgets('clearing the keyword shows all data again', (tester) async {
    final results = {
      '': [_candidate('c1', 'John Doe')],
      'jane': [_candidate('c2', 'Jane Smith')],
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchCandidatesProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
        ],
        child: const MaterialApp(home: SearchCandidateScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'jane');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Jane Smith'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsNothing);
  });

  testWidgets('scrolling to the bottom loads the next page', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final page1 = List.generate(20, (i) => _candidate('p1-$i', 'Candidate $i'));
    final page2 = [_candidate('p2', 'Candidate 20')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchCandidatesProvider.overrideWith2(
            (kw) => _PaginatedSearchNotifier(kw, [page1, page2]),
          ),
        ],
        child: const MaterialApp(home: SearchCandidateScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Candidate 20'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('Candidate 20'), findsOneWidget);
  });

  testWidgets('tapping a result opens the candidate detail page', (tester) async {
    final navigator = _FakeNavigator();
    final results = {
      '': [_candidate('c1', 'John Doe', jobId: 'j1')],
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchCandidatesProvider.overrideWith2(
            (kw) => _FakeSearchNotifier(kw, results),
          ),
          navigatorProvider.overrideWithValue(navigator),
        ],
        child: MaterialApp(
          navigatorKey: navigator.navigatorKey,
          home: const SearchCandidateScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('John Doe'));
    await tester.pump();
    expect(navigator.openedCandidates.first.cvId, 'c1');
  });

  testWidgets('swiping a result deletes the candidate', (tester) async {
    final notifier = _DeletableSearchNotifier('', [
      _candidate('c1', 'John Doe'),
      _candidate('c2', 'Jane Smith'),
    ]);
    final navigator = _FakeNavigator();
    late final _FakeJobDetailController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchCandidatesProvider.overrideWith2((kw) => notifier),
          jobDetailControllerProvider.overrideWith(
            (ref) => controller = _FakeJobDetailController(ref, notifier),
          ),
          navigatorProvider.overrideWithValue(navigator),
        ],
        child: MaterialApp(
          navigatorKey: navigator.navigatorKey,
          home: const SearchCandidateScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.text('John Doe'), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Delete this candidate?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(controller.deletedCvIds, ['c1']);
    expect(find.text('Candidate deleted'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsNothing);
    expect(find.text('Jane Smith'), findsOneWidget);
  });
}
