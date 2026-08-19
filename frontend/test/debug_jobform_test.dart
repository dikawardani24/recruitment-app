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

class _FakeNavigator implements AppNavigator {
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

  @override
  void goToHelp() {}

  @override
  void goToHelpCategory(String categoryId) {}
  @override void goToJobDetail(String jobId) {}
  @override void goToCandidateDetail(String jobId, CandidateResult candidate) {}
  @override void goToRankings(RankingsScreenData data) {}
  @override Future<bool> pushDeleteConfirm(DeleteConfirmArgs args) async => true;
  @override Future<void> pushActionResult(ActionResultData data) async {}
  @override void pop() => popCount++;
}

class _FakeCreateJob implements CreateJob {
  Object? error;
  Future<Job> result = Future.value(const Job(id: 'j1', title: 'T', description: '', status: 'open', createdAt: 'x'));
  @override
  Future<Job> call({required String title, required String description, File? jdFile, String? jdFileName}) async {
    if (error != null) throw error!;
    return await result;
  }
}

void main() {
  testWidgets('debug trim', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final navigator = _FakeNavigator();
    getIt.registerLazySingleton<CreateJob>(() => _FakeCreateJob());
    addTearDown(() => getIt.unregister<CreateJob>());

    await tester.pumpWidget(ProviderScope(
      overrides: [navigatorProvider.overrideWithValue(navigator)],
      child: const MaterialApp(home: JobFormScreen()),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), '  X  ');
    await tester.enterText(find.byType(TextFormField).at(1), '  Y  ');
    await tester.tap(find.text('Create job'));
    await tester.pump();
    await tester.pump();
    print('snackbar="Created \\"T\\""=${find.text('Created "T"').evaluate().length} failed=${find.textContaining('Failed to create job').evaluate().length}');
  });
}
