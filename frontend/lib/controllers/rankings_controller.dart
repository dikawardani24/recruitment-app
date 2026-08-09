import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../widgets/candidate_detail_sheet.dart';

/// Owns every rankings screen action. Today the screen is read-only and the
/// only interaction is opening the candidate detail sheet.
class RankingsController {
  /// Opens the candidate detail bottom sheet for a ranked candidate.
  void openCandidateDetails(
    BuildContext context,
    CandidateResult candidate,
  ) {
    showCandidateDetailSheet(context, candidate);
  }
}

final rankingsControllerProvider = Provider<RankingsController>(
  (ref) => RankingsController(),
);
