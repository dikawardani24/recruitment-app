import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/controllers/jobForm/job_form_controller.dart';
import 'package:ai_ats/di.dart';
import 'package:ai_ats/domain/models.dart';
import 'package:ai_ats/domain/usecases/create_job.dart';
import 'package:ai_ats/navigation/app_navigator.dart';
import 'package:ai_ats/providers.dart';

class _FakeNavigator implements AppNavigator {
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
  void goToJobDetail(String jobId) {}
  @override
  void goToCandidateDetail(String jobId, CandidateResult candidate) {}
  @override
  void goToRankings(RankingsScreenData data) {}
  @override
  Future<bool> pushDeleteConfirm(DeleteConfirmArgs args) async => true;
  @override
  Future<void> pushActionResult(ActionResultData data) async {}
  @override
  void pop() => popCount++;
}

class _FakeCreateJob implements CreateJob {
  final calls = <({String title, String description})>[];
  Object? error;
  late Future<Job> result;

  @override
  Future<Job> call({
    required String title,
    required String description,
    File? jdFile,
    String? jdFileName,
  }) async {
    calls.add((title: title, description: description));
    final e = error;
    if (e != null) throw e;
    return await result;
  }
}

class _SubmitHost extends ConsumerWidget {
  const _SubmitHost({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => ref.read(jobFormControllerProvider.notifier).submit(
                context,
                title: title,
                description: description,
              ),
              child: const Text('submit'),
            ),
          ),
        ),
      ),
    );
  }
}

Job _job() => const Job(
      id: 'j1',
      title: 'Backend Engineer',
      description: 'Build services',
      status: 'open',
      createdAt: '2026-08-06T14:05:00',
    );

void main() {
  late _FakeNavigator navigator;
  late _FakeCreateJob createJob;

  setUp(() {
    navigator = _FakeNavigator();
    createJob = _FakeCreateJob();
    getIt.registerLazySingleton<CreateJob>(() => createJob);
  });

  tearDown(() {
    getIt.unregister<CreateJob>();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [navigatorProvider.overrideWithValue(navigator)],
      );

  test('createJob shows the submitting state, then pops and resets', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final gate = Completer<Job>();
    createJob.result = gate.future;

    final pending = container
        .read(jobFormControllerProvider.notifier)
        .createJob(title: 'Backend Engineer', description: 'Build services');

    await Future<void>.delayed(Duration.zero);
    final busy = container.read(jobFormControllerProvider);
    expect(busy.submitting, isTrue);
    expect(busy.loadingMessage, 'Creating job…');

    gate.complete(_job());
    final job = await pending;

    expect(job.id, 'j1');
    expect(createJob.calls.single.title, 'Backend Engineer');
    expect(createJob.calls.single.description, 'Build services');
    expect(navigator.popCount, 1);
    expect(container.read(jobFormControllerProvider).submitting, isFalse);
  });

  test('createJob rethrows and resets the state when the call fails', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    createJob.error = Exception('network down');

    await expectLater(
      container
          .read(jobFormControllerProvider.notifier)
          .createJob(title: 'X', description: 'Y'),
      throwsException,
    );
    expect(navigator.popCount, 0);
    expect(container.read(jobFormControllerProvider).submitting, isFalse);
  });

  testWidgets('submit shows a confirmation snackbar on success', (tester) async {
    createJob.result = Future.value(_job());
    final container = makeContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _SubmitHost(title: 'Backend Engineer', description: 'X'),
      ),
    );

    await tester.tap(find.text('submit'));
    await tester.pump();

    expect(find.text('Created "Backend Engineer"'), findsOneWidget);
  });

  testWidgets('submit shows a failure snackbar when creation fails', (
    tester,
  ) async {
    createJob.error = Exception('network down');
    final container = makeContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _SubmitHost(title: 'Backend Engineer', description: 'X'),
      ),
    );

    await tester.tap(find.text('submit'));
    await tester.pump();

    expect(
      find.text('Failed to create job: Exception: network down'),
      findsOneWidget,
    );
  });
}
