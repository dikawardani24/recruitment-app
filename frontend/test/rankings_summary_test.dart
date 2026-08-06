import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/models.dart';
import 'package:ai_ats/widgets/rankings_summary.dart';

void main() {
  CandidateResult buildResult({
    required String name,
    required double score,
    String bucket = 'strong_match',
    List<String> skillGaps = const [],
  }) {
    return CandidateResult(
      cvId: 'cv-$name',
      fileName: '$name.pdf',
      status: 'ranked',
      candidateName: name,
      overallScore: score,
      bucket: bucket,
      strengths: const ['Detail oriented'],
      weaknesses: const [],
      skillGaps: skillGaps,
    );
  }

  Widget buildApp(List<CandidateResult> results) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [RankingsSummary(results: results)],
          ),
        ),
      ),
    );
  }

  testWidgets('renders score overview, buckets and missing skills', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildApp([
        buildResult(
          name: 'Alice',
          score: 0.92,
          skillGaps: const ['Rust'],
        ),
        buildResult(
          name: 'Bob',
          score: 0.61,
          bucket: 'possible_match',
          skillGaps: const ['Rust', 'Kafka'],
        ),
        buildResult(name: 'Carol', score: 0.72, bucket: 'good_match'),
      ]),
    );
    await tester.pump();

    expect(find.text('Score overview'), findsOneWidget);
    expect(find.text('Buckets'), findsOneWidget);
    expect(find.text('Missing skills'), findsOneWidget);
    expect(find.text('3 candidates'), findsOneWidget);
    expect(find.text('Rust'), findsWidgets);
    expect(find.text('Kafka'), findsOneWidget);

    final progressIndicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator).first,
    );
    expect(progressIndicator.color, Colors.red.shade300);

    expect(tester.takeException(), isNull);
  });

  testWidgets('no summary when all candidates lack scores', (tester) async {
    await tester.pumpWidget(
      buildApp([
        CandidateResult(
          cvId: 'cv-1',
          fileName: 'x.pdf',
          status: 'error',
          error: 'parse failed',
        ),
      ]),
    );
    await tester.pump();

    expect(find.text('Score overview'), findsNothing);
    expect(find.text('Buckets'), findsNothing);
    expect(find.text('Missing skills'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at very narrow width', (tester) async {
    tester.view.physicalSize = const Size(120, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildApp([
        buildResult(
          name: 'Alice',
          score: 0.92,
          skillGaps: const ['Rust'],
        ),
        buildResult(
          name: 'Bob',
          score: 0.61,
          bucket: 'possible_match',
          skillGaps: const ['Kafka'],
        ),
        buildResult(name: 'Carol', score: 0.72, bucket: 'good_match'),
      ]),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}