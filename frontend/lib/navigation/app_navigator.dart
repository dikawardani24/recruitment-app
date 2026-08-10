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

/// Data plus callbacks passed to the delete confirmation screen.
///
/// [onConfirm] performs the deletion (throws on failure) and [onDeleted] runs
/// after a successful delete, e.g. to navigate away.
class DeleteConfirmArgs {
  final DeleteConfirmData data;
  final ActionResultData successResult;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onDeleted;

  const DeleteConfirmArgs({
    required this.data,
    required this.successResult,
    required this.onConfirm,
    this.onDeleted = _noopAfterDelete,
  });
}

Future<void> _noopAfterDelete() async {}

/// Defines every navigation that can be performed in the app.
///
/// Screens depend on this interface instead of go_router directly. The
/// concrete implementation decides how to translate a call into an actual
/// route change.
abstract class AppNavigator {
  void goToJobs();

  void goToJobForm();

  void goToSettings();

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
