import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/controllers/job_detail_controller.dart';
import 'package:ai_ats/domain/models.dart';
import 'package:ai_ats/navigation/app_navigator.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/screens/job_detail_screen.dart';

/// Navigator that records navigation calls instead of touching go_router.
class _FakeNavigator implements AppNavigator {
  final wentToJobs = <String>[];
  final wentToCandidateDetail = <String>[];

  @override
  void goToJobs() => wentToJobs.add('goToJobs');

  @override
  void goToJobForm() {}

  @override
  void goToSettings() {}

  @override
  void goToJobDetail(String jobId) {}

  @override
  void goToCandidateDetail(String jobId, CandidateResult candidate) =>
      wentToCandidateDetail.add(candidate.cvId ?? candidate.fileName);

  @override
  void goToRankings(RankingsScreenData data) {}

  @override
  void pop() {}
}

/// Notifier that records deletes/ranks and mirrors the real
/// [JobDetailNotifier] behaviour of refreshing the CV list after a candidate
/// is removed.
class _FakeDetailNotifier extends JobDetailNotifier {
  final List<CandidateResult> cvs;
  final deletedCvs = <String>[];
  final deletedJobs = <String>[];
  final rankedCvs = <String>[];
  final rankedJobs = <String>[];

  _FakeDetailNotifier(this.cvs);

  @override
  Future<void> deleteCv(String jobId, String cvId) async {
    deletedCvs.add(cvId);
    cvs.removeWhere((c) => c.cvId == cvId);
    ref.invalidate(cvsProvider(jobId));
    await ref.read(cvsProvider(jobId).future);
  }

  @override
  Future<void> deleteJob(String jobId) async {
    deletedJobs.add(jobId);
  }

  @override
  Future<RankResponse> rankJob(String jobId) async {
    rankedJobs.add(jobId);
    return const RankResponse(source: 'rules', results: []);
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
  Job buildJob({required String description}) {
    return Job(
      id: 'job-1',
      title: 'Backend Engineer',
      description: description,
      status: 'open',
      createdAt: '2026-01-01T00:00:00',
      requirements: JobRequirements(requiredSkills: const ['Dart', 'Flutter']),
    );
  }

  Widget buildApp(
    Job job, {
    List<CandidateResult> cvs = const [],
    List<CandidateResult> rankings = const [],
    _FakeDetailNotifier? detailNotifier,
    _FakeNavigator? navigator,
  }) {
    return ProviderScope(
      overrides: [
        jobProvider('job-1').overrideWith((ref) async => job),
        cvsProvider('job-1').overrideWith((ref) async => cvs),
        rankingsProvider('job-1').overrideWith((ref) async => rankings),
        if (detailNotifier != null)
          jobDetailStateProvider.overrideWith(() => detailNotifier),
        navigatorProvider.overrideWithValue(navigator ?? _FakeNavigator()),
      ],
      child: const MaterialApp(home: JobDetailScreen(jobId: 'job-1')),
    );
  }

  CandidateResult buildRankedResult({
    required String name,
    required double score,
    String bucket = 'strong_match',
  }) {
    return CandidateResult(
      cvId: 'cv-$name',
      fileName: '$name.pdf',
      status: 'ranked',
      candidateName: name,
      overallScore: score,
      bucket: bucket,
      source: 'rules',
    );
  }

  CandidateResult ranked(String id, String name) {
    return CandidateResult(
      cvId: id,
      fileName: '$name.pdf',
      candidateName: name,
      status: 'ranked',
      overallScore: 0.9,
      bucket: 'strong_match',
      skills: const ['Dart', 'Flutter'],
    );
  }

  testWidgets('long description collapses to 10 lines and expands', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final longDescription = List.generate(
      40,
      (i) => 'Line of description number $i',
    ).join('\n');
    await tester.pumpWidget(buildApp(buildJob(description: longDescription)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Show more'), findsOneWidget);

    await tester.tap(find.text('Show more'));
    await tester.pump();

    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('short description shows no toggle', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildApp(buildJob(description: 'Short description')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Show more'), findsNothing);
    expect(find.text('Short description'), findsOneWidget);
  });

  testWidgets('shows not-ranked hint when CVs exist but none are ranked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildApp(
        buildJob(description: 'Short description'),
        cvs: [
          CandidateResult(
            cvId: 'cv-1',
            fileName: 'alice.pdf',
            status: 'uploaded',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Not ranked yet'), findsOneWidget);
    expect(find.text('Buckets'), findsNothing);
  });

  testWidgets('shows bucket donut when candidates are ranked', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildApp(
        buildJob(description: 'Short description'),
        cvs: [buildRankedResult(name: 'Alice', score: 0.9)],
        rankings: [
          buildRankedResult(name: 'Alice', score: 0.9),
          buildRankedResult(name: 'Bob', score: 0.55, bucket: 'possible_match'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Not ranked yet'), findsNothing);
    expect(find.text('Buckets'), findsOneWidget);
    expect(find.text('View full ranking'), findsOneWidget);
    expect(find.text('Strong Match'), findsWidgets);
    expect(find.text('Possible Match'), findsWidgets);
  });

  testWidgets('tapping a ranked candidate opens the candidate detail page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final alice = CandidateResult(
      cvId: 'cv-1',
      fileName: 'alice.pdf',
      candidateName: 'Alice',
      status: 'ranked',
      overallScore: 0.9,
      bucket: 'strong_match',
      recommendation: 'Strong hire',
      strengths: const ['Dart', 'Flutter'],
      explanation: 'Matches all required skills.',
      rankedBy: 'llm',
    );
    final navigator = _FakeNavigator();
    await tester.pumpWidget(
      buildApp(
        buildJob(description: 'Short description'),
        cvs: [alice],
        navigator: navigator,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('AI'), findsOneWidget);

    await tester.tap(find.text('Alice'));
    await tester.pump();

    expect(navigator.wentToCandidateDetail, ['cv-1']);
  });

  testWidgets('tapping an unranked candidate opens the candidate detail page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigator = _FakeNavigator();
    await tester.pumpWidget(
      buildApp(
        buildJob(description: 'Short description'),
        cvs: [
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
        ],
        navigator: navigator,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Alice'));
    await tester.pump();

    expect(navigator.wentToCandidateDetail, ['cv-1']);
  });

  group('candidate deletion', () {
    testWidgets('swipe reveals confirmation with candidate details', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cvs = [
        ranked('cv-1', 'Alice'),
        CandidateResult(cvId: 'cv-2', fileName: 'bob.pdf', status: 'uploaded'),
      ];
      final controller = _FakeDetailNotifier(cvs);
      await tester.pumpWidget(
        buildApp(
          buildJob(description: 'Short description'),
          cvs: cvs,
          detailNotifier: controller,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.fling(find.text('Alice'), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Delete this candidate?'), findsOneWidget);
      expect(find.text('Delete candidate'), findsOneWidget);
      expect(find.text('Alice'), findsWidgets);
      expect(find.text('Alice.pdf'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('confirming removes the candidate from the list', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cvs = [
        ranked('cv-1', 'Alice'),
        CandidateResult(
          cvId: 'cv-2',
          fileName: 'bob.pdf',
          candidateName: 'Bob',
          status: 'uploaded',
        ),
      ];
      final controller = _FakeDetailNotifier(cvs);
      await tester.pumpWidget(
        buildApp(
          buildJob(description: 'Short description'),
          cvs: cvs,
          detailNotifier: controller,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.fling(find.text('Alice'), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete candidate'));
      await tester.pumpAndSettle();

      expect(controller.deletedCvs, ['cv-1']);
      expect(find.text('Candidate deleted'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsNothing);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Candidate deleted'), findsNothing);
    });
  });

  group('job deletion from AppBar', () {
    testWidgets('delete action shows confirmation and deletes the job', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cvs = [ranked('cv-1', 'Alice')];
      final controller = _FakeDetailNotifier(cvs);
      final navigator = _FakeNavigator();
      await tester.pumpWidget(
        buildApp(
          buildJob(description: 'Short description'),
          cvs: cvs,
          detailNotifier: controller,
          navigator: navigator,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete this job?'), findsOneWidget);
      expect(find.text('Alice'), findsWidgets);
      expect(
        find.text('This job and its 1 candidate will be permanently removed.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete job'));
      await tester.pumpAndSettle();

      expect(controller.deletedJobs, ['job-1']);
      expect(find.text('Job deleted'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(navigator.wentToJobs, ['goToJobs']);
    });

    testWidgets('cancelling from the confirm screen deletes nothing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cvs = [ranked('cv-1', 'Alice')];
      final controller = _FakeDetailNotifier(cvs);
      await tester.pumpWidget(
        buildApp(
          buildJob(description: 'Short description'),
          cvs: cvs,
          detailNotifier: controller,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.deletedJobs, isEmpty);
      expect(find.text('Delete this job?'), findsNothing);
      expect(find.text('Backend Engineer'), findsNWidgets(2));
    });
  });

  group('bulk rank', () {
    testWidgets('shows an info dialog when there are no candidates', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakeDetailNotifier([]);
      await tester.pumpWidget(
        buildApp(
          buildJob(description: 'Short description'),
          detailNotifier: controller,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Rank CVs'));
      await tester.pumpAndSettle();

      expect(find.text('No candidates to rank'), findsOneWidget);
      expect(controller.rankedJobs, isEmpty);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('No candidates to rank'), findsNothing);
    });

    testWidgets('asks for confirmation before re-ranking already-ranked CVs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cvs = [ranked('cv-1', 'Alice'), ranked('cv-2', 'Bob')];
      final controller = _FakeDetailNotifier(cvs);
      await tester.pumpWidget(
        buildApp(
          buildJob(description: 'Short description'),
          cvs: cvs,
          detailNotifier: controller,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Rank CVs'));
      await tester.pumpAndSettle();

      expect(find.text('Re-rank all candidates?'), findsOneWidget);
      expect(controller.rankedJobs, isEmpty);

      await tester.tap(find.text('Re-rank all'));
      await tester.pumpAndSettle();

      expect(controller.rankedJobs, ['job-1']);
      expect(find.text('Re-rank all candidates?'), findsNothing);
    });

    testWidgets('cancelling re-rank confirmation does not rank', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cvs = [ranked('cv-1', 'Alice')];
      final controller = _FakeDetailNotifier(cvs);
      await tester.pumpWidget(
        buildApp(
          buildJob(description: 'Short description'),
          cvs: cvs,
          detailNotifier: controller,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Rank CVs'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.rankedJobs, isEmpty);
      expect(find.text('Re-rank all candidates?'), findsNothing);
    });

    testWidgets('rank runs directly when some CVs are unranked', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cvs = [
        ranked('cv-1', 'Alice'),
        CandidateResult(
          cvId: 'cv-2',
          fileName: 'bob.pdf',
          candidateName: 'Bob',
          status: 'completed',
        ),
      ];
      final controller = _FakeDetailNotifier(cvs);
      await tester.pumpWidget(
        buildApp(
          buildJob(description: 'Short description'),
          cvs: cvs,
          detailNotifier: controller,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Rank CVs'));
      await tester.pumpAndSettle();

      expect(find.text('Re-rank all candidates?'), findsNothing);
      expect(controller.rankedJobs, ['job-1']);
    });

    testWidgets('lists ranked candidates in score order before the rest', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cvs = [
        CandidateResult(
          cvId: 'cv-1',
          fileName: 'low.pdf',
          candidateName: 'Low',
          status: 'completed',
        ),
        CandidateResult(
          cvId: 'cv-2',
          fileName: 'bob.pdf',
          candidateName: 'Bob',
          status: 'ranked',
          overallScore: 0.4,
          bucket: 'possible_match',
        ),
        CandidateResult(
          cvId: 'cv-3',
          fileName: 'alice.pdf',
          candidateName: 'Alice',
          status: 'ranked',
          overallScore: 0.9,
          bucket: 'strong_match',
        ),
      ];
      await tester.pumpWidget(
        buildApp(buildJob(description: 'Short description'), cvs: cvs),
      );
      await tester.pump();
      await tester.pump();

      final aliceY = tester.getTopLeft(find.text('Alice')).dy;
      final bobY = tester.getTopLeft(find.text('Bob')).dy;
      final lowY = tester.getTopLeft(find.text('Low')).dy;

      expect(aliceY, lessThan(bobY));
      expect(bobY, lessThan(lowY));
    });

    testWidgets('shows an info dialog when no candidates are ready to rank', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cvs = [
        CandidateResult(
          cvId: 'cv-1',
          fileName: 'alice.pdf',
          candidateName: 'Alice',
          status: 'processing',
        ),
        CandidateResult(
          cvId: 'cv-2',
          fileName: 'bob.pdf',
          candidateName: 'Bob',
          status: 'uploaded',
        ),
      ];
      final controller = _FakeDetailNotifier(cvs);
      await tester.pumpWidget(
        buildApp(
          buildJob(description: 'Short description'),
          cvs: cvs,
          detailNotifier: controller,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Rank CVs'));
      await tester.pumpAndSettle();

      expect(find.text('Ranking unavailable'), findsOneWidget);
      expect(controller.rankedJobs, isEmpty);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Ranking unavailable'), findsNothing);
    });
  });
}
