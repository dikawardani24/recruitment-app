import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../providers.dart';
import 'jobDetail/job_detail_controller.dart';

class CandidateSearchController {
  final Ref _ref;

  CandidateSearchController(this._ref);

  void openCandidateDetails(CandidateResult cv) {
    final jobId = cv.jobId;
    if (jobId == null) return;
    _ref.read(navigatorProvider).goToCandidateDetail(jobId, cv);
  }

  Future<bool> deleteCandidate(CandidateResult cv) async {
    final jobId = cv.jobId;
    if (jobId == null) return false;
    return _ref.read(jobDetailControllerProvider).deleteCv(jobId, cv);
  }
}

final candidateSearchControllerProvider = Provider<CandidateSearchController>(
  (ref) => CandidateSearchController(ref),
);
