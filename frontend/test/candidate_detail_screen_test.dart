import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/controllers/jobDetail/job_detail_notifier.dart';
import 'package:ai_ats/domain/models.dart';
import 'package:ai_ats/navigation/app_navigator.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/screens/action_result_screen.dart';
import 'package:ai_ats/screens/candidate_detail_screen.dart';
import 'package:ai_ats/screens/delete_confirm_screen.dart';

/// Navigator that records pops and pushes the real confirm/result screens onto
/// the test widget tree.
class _FakeNavigator implements AppNavigator {
  final navigatorKey = GlobalKey<NavigatorState>();
  int pops = 0;

  @override
  void goToJobs() {}

  @override
  void goToJobForm() {}

  @override
  void goToSettings() {}

  @override
  void goToJobDetail(String jobId) {}

  @override
  void goToCandidateDetail(String jobId, CandidateResult candidate) {}

  @override
  void goToRankings(RankingsScreenData data) {}

  @override
  Future<bool> pushDeleteConfirm(DeleteConfirmData data) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;
    return await navigator.push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => DeleteConfirmScreen(data: data),
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
  void pop() => pops++;
}

/// Notifier that records ranks/deletes and refreshes the CV list like the
/// real [JobDetailNotifier].
class _FakeDetailNotifier extends JobDetailNotifier {
  final List<CandidateResult> cvs;
  final deletedCvs = <String>[];
  final rankedCvs = <String>[];

  _FakeDetailNotifier(this.cvs);

  @override
  Future<void> deleteCv(String jobId, String cvId) async {
    deletedCvs.add(cvId);
    cvs.removeWhere((c) => c.cvId == cvId);
    ref.invalidate(cvsProvider(jobId));
    await ref.read(cvsProvider(jobId).future);
  }

  @override
  Future<void> rankCv(String jobId, String cvId) async {
    rankedCvs.add(cvId);
    final index = cvs.indexWhere((c) => c.cvId == cvId);
    if (index >= 0) {
      cvs[index] = CandidateResult(
        cvId: cvId,
        fileName: cvs[index].fileName,
        candidateName: cvs[index].candidateName,
        status: 'ranked',
        overallScore: 0.9,
        bucket: 'strong_match',
      );
    }
    ref.invalidate(cvsProvider(jobId));
    ref.invalidate(rankingsProvider(jobId));
    await ref.read(cvsProvider(jobId).future);
  }
}

void main() {
  CandidateResult ranked({String id = 'cv-1', String name = 'Alice'}) {
    return CandidateResult(
      cvId: id,
      fileName: '$name.pdf',
      candidateName: name,
      status: 'ranked',
      overallScore: 0.9,
      bucket: 'strong_match',
      strengths: const ['Dart', 'Flutter'],
      explanation: 'Matches all required skills.',
      rankedBy: 'llm',
    );
  }

  Widget buildApp({
    required CandidateResult candidate,
    required _FakeDetailNotifier notifier,
    _FakeNavigator? navigator,
  }) {
    final nav = navigator ?? _FakeNavigator();
    return ProviderScope(
      overrides: [
        cvsProvider('job-1').overrideWith((ref) async => notifier.cvs),
        jobDetailStateProvider.overrideWith(() => notifier),
        navigatorProvider.overrideWithValue(nav),
      ],
      child: MaterialApp(
        navigatorKey: nav.navigatorKey,
        home: const CandidateDetailScreen(
          jobId: 'job-1',
          cvId: 'cv-1',
          initial: null,
        ),
      ),
    );
  }

  testWidgets('ranked candidate shows score, strengths, and explanation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _FakeDetailNotifier([ranked()]);
    await tester.pumpWidget(buildApp(candidate: ranked(), notifier: notifier));
    await tester.pump();
    await tester.pump();

    expect(find.text('Match Score'), findsOneWidget);
    expect(find.text('90%'), findsWidgets);
    expect(find.text('Strong Match'), findsWidgets);
    expect(find.text('Ranked by'), findsOneWidget);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('STRENGTHS'), findsOneWidget);
    expect(find.text('Dart'), findsWidgets);
    expect(find.text('Explanation'), findsOneWidget);
    expect(find.text('Re-rank CV'), findsOneWidget);
  });

  testWidgets('unranked candidate shows status and profile sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _FakeDetailNotifier([
      CandidateResult(
        cvId: 'cv-1',
        fileName: 'alice.pdf',
        candidateName: 'Alice',
        status: 'uploaded',
        skills: const ['Dart', 'Flutter'],
        yearsExperience: 5,
        education: 'Bachelor of Science',
        certifications: const ['AWS Certified'],
      ),
    ]);
    await tester.pumpWidget(
      buildApp(candidate: notifier.cvs.first, notifier: notifier),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Status'), findsOneWidget);
    expect(find.text('uploaded'), findsWidgets);
    expect(
      find.text('This candidate has not been ranked yet.'),
      findsOneWidget,
    );
    expect(find.text('Rank this CV'), findsNothing);
    expect(find.text('Match Score'), findsNothing);
    expect(find.text('SKILLS'), findsOneWidget);
    expect(find.text('Dart'), findsWidgets);
    expect(find.text('EXPERIENCE'), findsOneWidget);
    expect(find.text('5 years'), findsOneWidget);
    expect(find.text('EDUCATION'), findsOneWidget);
    expect(find.text('Bachelor of Science'), findsOneWidget);
    expect(find.text('CERTIFICATIONS'), findsOneWidget);
    expect(find.text('AWS Certified'), findsOneWidget);
  });

  testWidgets('a candidate that is not ready shows no rank button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _FakeDetailNotifier([
      CandidateResult(
        cvId: 'cv-1',
        fileName: 'alice.pdf',
        candidateName: 'Alice',
        status: 'processing',
      ),
    ]);
    await tester.pumpWidget(
      buildApp(candidate: notifier.cvs.first, notifier: notifier),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Rank this CV'), findsNothing);
    expect(find.text('Re-rank CV'), findsNothing);
  });

  testWidgets('ranking an unranked candidate ranks and refreshes the page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _FakeDetailNotifier([
      CandidateResult(
        cvId: 'cv-1',
        fileName: 'alice.pdf',
        candidateName: 'Alice',
        status: 'completed',
      ),
    ]);
    await tester.pumpWidget(
      buildApp(candidate: notifier.cvs.first, notifier: notifier),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Rank this CV'), findsOneWidget);

    await tester.tap(find.text('Rank this CV'));
    await tester.pumpAndSettle();

    expect(notifier.rankedCvs, ['cv-1']);
    expect(find.text('Re-rank CV'), findsOneWidget);
    expect(find.text('90%'), findsWidgets);
  });

  testWidgets('ranked candidate can be re-ranked', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _FakeDetailNotifier([ranked()]);
    await tester.pumpWidget(buildApp(candidate: ranked(), notifier: notifier));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Re-rank CV'));
    await tester.pumpAndSettle();

    expect(notifier.rankedCvs, ['cv-1']);
  });

  testWidgets('delete confirms, deletes, and pops the page', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _FakeDetailNotifier([ranked()]);
    final navigator = _FakeNavigator();
    await tester.pumpWidget(
      buildApp(candidate: ranked(), notifier: notifier, navigator: navigator),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete this candidate?'), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Alice.pdf'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(notifier.deletedCvs, ['cv-1']);
    expect(find.text('Candidate deleted'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(navigator.pops, 1);
  });

  testWidgets('cancelling the delete confirmation deletes nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _FakeDetailNotifier([ranked()]);
    final navigator = _FakeNavigator();
    await tester.pumpWidget(
      buildApp(candidate: ranked(), notifier: notifier, navigator: navigator),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(notifier.deletedCvs, isEmpty);
    expect(navigator.pops, 0);
    expect(find.text('Delete this candidate?'), findsNothing);
  });

  testWidgets('candidate without a cvId cannot be deleted', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _FakeDetailNotifier([
      CandidateResult(
        fileName: 'alice.pdf',
        candidateName: 'Alice',
        status: 'uploaded',
      ),
    ]);
    await tester.pumpWidget(
      buildApp(candidate: notifier.cvs.first, notifier: notifier),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
