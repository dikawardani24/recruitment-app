import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_navigator.dart';
import '../../providers.dart';
import 'delete_confirm_state.dart';

/// Owns the confirm → delete → result flow for the delete confirmation
/// screen. Callers register the delete operation (and its success page) with
/// [prepare] before pushing the screen; [confirm] runs it, reports the
/// outcome, and runs the follow-up.
class DeleteConfirmController extends Notifier<DeleteConfirmState> {
  Future<void> Function()? _onConfirm;
  ActionResultData? _successResult;

  @override
  DeleteConfirmState build() => const DeleteConfirmState();

  /// Registers the deletion that [confirm] will run and the result page to
  /// show when it succeeds.
  void prepare({
    required Future<void> Function() onConfirm,
    required ActionResultData successResult,
  }) {
    _onConfirm = onConfirm;
    _successResult = successResult;
  }

  /// Runs the registered deletion, shows the outcome, runs [DeleteConfirmArgs.onDeleted],
  /// and resolves to `true` only when the deletion succeeded.
  Future<bool> confirm(DeleteConfirmArgs args) async {
    final onConfirm = _onConfirm;
    final successResult = _successResult;
    if (onConfirm == null || successResult == null) return false;

    state = const DeleteConfirmState(deleting: true);
    try {
      await onConfirm();
      await ref.read(navigatorProvider).pushActionResult(successResult);
      await args.onDeleted?.call();
      return true;
    } catch (e) {
      await ref.read(navigatorProvider).pushActionResult(
        ActionResultData(
          success: false,
          title: 'Delete failed',
          message: '$e',
        ),
      );
      return false;
    } finally {
      state = const DeleteConfirmState();
      _onConfirm = null;
      _successResult = null;
    }
  }
}

final deleteConfirmControllerProvider =
    NotifierProvider<DeleteConfirmController, DeleteConfirmState>(
      DeleteConfirmController.new,
    );
