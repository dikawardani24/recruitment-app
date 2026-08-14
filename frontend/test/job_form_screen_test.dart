import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/di.dart';
import 'package:ai_ats/domain/models.dart';
import 'package:ai_ats/domain/usecases/create_job.dart';
import 'package:ai_ats/navigation/app_navigator.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/screens/job_form_screen.dart';
import 'package:ai_ats/widgets/loading_overlay.dart';

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
  void goToApiKey() {}
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
  Future<Job> result = Future.value(_job());

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

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [navigatorProvider.overrideWithValue(navigator)],
        child: const MaterialApp(home: JobFormScreen()),
      ),
    );
    // Let DeferredPage arm its post-frame callback and reveal the form.
    await tester.pump();
  }

  testWidgets('renders the job creation form', (tester) async {
    await pumpForm(tester);

    expect(find.text('Create a job'), findsOneWidget);
    expect(find.text('Job title'), findsOneWidget);
    expect(find.text('Job description'), findsOneWidget);
    expect(find.text('Upload JD file (optional)'), findsOneWidget);
    expect(find.text('Create job'), findsOneWidget);
  });

  testWidgets('empty title blocks submission with a validation message', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(find.byType(TextFormField).at(1), 'Build services');
    await tester.tap(find.text('Create job'));
    await tester.pump();

    expect(find.text('Title is required'), findsOneWidget);
    expect(createJob.calls, isEmpty);
  });

  testWidgets('shows the busy state while creating, then a success snackbar', (
    tester,
  ) async {
    final gate = Completer<Job>();
    createJob.result = gate.future;
    await pumpForm(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Backend Engineer');
    await tester.enterText(find.byType(TextFormField).at(1), 'Build services');

    await tester.tap(find.text('Create job'));
    await tester.pump();

    // Busy: button label changes, overlay appears and the button is disabled.
    expect(find.text('Creating…'), findsWidgets);
    expect(find.byType(LoadingOverlay), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Creating…'),
    );
    expect(button.onPressed, isNull);

    gate.complete(_job());
    await tester.pump();
    await tester.pump();

    expect(createJob.calls.single.title, 'Backend Engineer');
    expect(createJob.calls.single.description, 'Build services');
    expect(navigator.popCount, 1);
    expect(find.text('Created "Backend Engineer"'), findsOneWidget);
  });

  testWidgets('trims whitespace from title and description before submitting', (
    tester,
  ) async {
    final gate = Completer<Job>();
    createJob.result = gate.future;
    await pumpForm(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      '  Backend Engineer  ',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '  Build  ');
    await tester.tap(find.text('Create job'));
    await tester.pump();

    gate.complete(_job());
    await tester.pump();
    await tester.pump();

    expect(createJob.calls.single.title, 'Backend Engineer');
    expect(createJob.calls.single.description, 'Build');
  });

  testWidgets('shows a failure snackbar when creation fails', (tester) async {
    createJob.error = Exception('network down');
    await pumpForm(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Backend Engineer');
    await tester.enterText(find.byType(TextFormField).at(1), 'Build services');
    await tester.tap(find.text('Create job'));
    await tester.pump();

    expect(
      find.text('Failed to create job: Exception: network down'),
      findsOneWidget,
    );
    expect(navigator.popCount, 0);
  });
}
