import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/controllers/jobDetail/job_detail_notifier.dart';
import 'package:ai_ats/domain/models/candidate_result.dart';
import 'package:ai_ats/providers.dart';

void main() {
  testWidgets('does not poll until a successful import explicitly starts it', (
    tester,
  ) async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        cvsProvider('job-1').overrideWith((ref) async {
          calls++;
          return const <CandidateResult>[];
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(jobDetailStateProvider.notifier);
    await tester.pump(const Duration(seconds: 4));

    expect(calls, 0);
  });

  testWidgets(
    'successful imports start one polling loop and terminal CVs stop it',
    (tester) async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          cvsProvider('job-1').overrideWith((ref) async {
            calls++;
            return [
              CandidateResult(
                cvId: 'cv-1',
                fileName: 'alice.pdf',
                status: calls == 1 ? 'processing' : 'completed',
              ),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(jobDetailStateProvider.notifier);
      notifier.startPolling('job-1', 'import-1');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(calls, 1);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      final callsAfterCompletion = calls;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(calls, callsAfterCompletion);
    },
  );

  testWidgets('failed processing stops polling', (tester) async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        cvsProvider('job-1').overrideWith((ref) async {
          calls++;
          return const [
            CandidateResult(
              cvId: 'cv-1',
              fileName: 'alice.pdf',
              status: 'failed',
            ),
          ];
        }),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(jobDetailStateProvider.notifier);
    notifier.startPolling('job-1', 'import-1');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final callsAfterFailure = calls;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(callsAfterFailure, greaterThan(0));
    expect(calls, callsAfterFailure);
  });

  testWidgets(
    'new imports replace previous polling and explicit disposal stops it',
    (tester) async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          cvsProvider('job-1').overrideWith((ref) async {
            calls++;
            return const [
              CandidateResult(
                cvId: 'cv-1',
                fileName: 'alice.pdf',
                status: 'processing',
              ),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(jobDetailStateProvider.notifier);
      notifier.startPolling('job-1', 'import-1');
      notifier.startPolling('job-1', 'import-2');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(calls, 1);

      notifier.stopPolling('job-1');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(calls, 1);
    },
  );
}
