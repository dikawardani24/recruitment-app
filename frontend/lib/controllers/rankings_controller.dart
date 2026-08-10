import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../providers.dart';

/// Owns every rankings screen action. Today the screen is read-only and the
/// only interaction is opening the candidate detail page.
class RankingsController {
  RankingsController(this._ref);

  final Ref _ref;

  /// Opens the candidate detail page for a ranked candidate.
  void openCandidateDetails(String jobId, CandidateResult candidate) {
    _ref.read(navigatorProvider).goToCandidateDetail(jobId, candidate);
  }
}

final rankingsControllerProvider = Provider<RankingsController>(
  (ref) => RankingsController(ref),
);
