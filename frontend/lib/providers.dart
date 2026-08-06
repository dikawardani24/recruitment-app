import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'models.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

final jobsProvider = FutureProvider<List<Job>>((ref) {
  return ref.read(apiClientProvider).listJobs();
});

final jobProvider = FutureProvider.family<Job, String>((ref, jobId) {
  return ref.read(apiClientProvider).getJob(jobId);
});

final cvsProvider = FutureProvider.family<List<CandidateResult>, String>((ref, jobId) {
  return ref.read(apiClientProvider).listCvs(jobId);
});

final rankingsProvider = FutureProvider.family<List<CandidateResult>, String>((ref, jobId) {
  return ref.read(apiClientProvider).getRankings(jobId);
});
