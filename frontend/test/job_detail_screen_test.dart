import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/models.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/screens/job_detail_screen.dart';

void main() {
  Job buildJob({required String description}) {
    return Job(
      id: 'job-1',
      title: 'Backend Engineer',
      description: description,
      status: 'open',
      createdAt: '2026-01-01T00:00:00',
      requirements: JobRequirements(
        requiredSkills: const ['Dart', 'Flutter'],
      ),
    );
  }

  Widget buildApp(Job job) {
    return ProviderScope(
      overrides: [
        jobProvider('job-1').overrideWith((ref) async => job),
        cvsProvider('job-1').overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: JobDetailScreen(jobId: 'job-1')),
    );
  }

  testWidgets('long description collapses to 3 lines and expands', (
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

    await tester.pumpWidget(buildApp(buildJob(description: 'Short description')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Show more'), findsNothing);
    expect(find.text('Short description'), findsOneWidget);
  });
}
