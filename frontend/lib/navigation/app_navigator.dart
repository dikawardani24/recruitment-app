import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Data passed to the rankings screen when navigating to it.
class RankingsScreenData {
  final String jobId;
  final String jobTitle;
  final String source;

  const RankingsScreenData({
    required this.jobId,
    required this.jobTitle,
    required this.source,
  });
}

/// Data passed to the delete confirmation screen when navigating to it.
class DeleteConfirmData {
  final String title;
  final String message;
  final List<Widget> details;

  const DeleteConfirmData({
    required this.title,
    required this.message,
    this.details = const [],
  });
}

/// Data passed to the action result screen when navigating to it.
class ActionResultData {
  final bool success;
  final String title;
  final String? message;

  const ActionResultData({
    required this.success,
    required this.title,
    this.message,
  });
}

/// Data passed to the delete confirmation screen.
///
/// [onDeleted] runs after a successful delete, e.g. to navigate away.
/// The delete operation itself is registered on [DeleteConfirmController]
/// before the screen is pushed.
class DeleteConfirmArgs {
  final DeleteConfirmData data;
  final Future<void> Function()? onDeleted;

  const DeleteConfirmArgs({
    required this.data,
    this.onDeleted,
  });
}

/// Defines every navigation that can be performed in the app.
///
/// Screens depend on this interface instead of go_router directly. The
/// concrete implementation decides how to translate a call into an actual
/// route change.
abstract class AppNavigator {
  void goToJobs();

  void goToJobForm();

  void goToSettings();

  void goToSearchJobs();

  void goToSearchCandidates();

  void goToSearch();

  void goToChat();

  void goToJobDetail(String jobId);

  void goToCandidateDetail(String jobId, CandidateResult candidate);

  void goToRankings(RankingsScreenData data);

  /// Pushes the delete confirmation screen, which runs the deletion and
  /// resolves to `true` only when it succeeded.
  Future<bool> pushDeleteConfirm(DeleteConfirmArgs args);

  /// Pushes the action result screen; resolves once the user dismisses it.
  Future<void> pushActionResult(ActionResultData data);

  void pop();
}
