import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/models.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/screens/job_list_screen.dart';

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
      Job(
        id: 'j1',
        title: 'Backend Engineer',
        description: '',
        status: 'open',
        createdAt: '2026-08-06T14:05:00',
        candidateCount: 12,
      ),
      Job(
        id: 'j2',
        title: 'Mobile Developer',
        description: '',
        status: 'open',
        createdAt: '2026-08-06T14:05:00',
        candidateCount: 3,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jobsProvider.overrideWith((ref) async => jobs)],
        child: const MaterialApp(home: JobListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('12 candidates'), findsOneWidget);
    expect(find.text('3 candidates'), findsOneWidget);
    expect(find.text('15 candidates · 2 jobs'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
  });
}
