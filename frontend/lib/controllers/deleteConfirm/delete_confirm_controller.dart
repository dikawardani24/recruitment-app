import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_navigator.dart';
import '../../providers.dart';
import 'delete_confirm_state.dart';

/// Owns the confirm → delete → result flow for the delete confirmation
/// screen. Callers supply the deletion operation via [DeleteConfirmArgs];
/// this controller runs it, reports the outcome, and runs the follow-up.
class DeleteConfirmController extends Notifier<DeleteConfirmState> {
  @override
  DeleteConfirmState build() => const DeleteConfirmState();

  /// Runs [args.onConfirm], shows the outcome, runs [args.onDeleted], and
  /// resolves to `true` only when the deletion succeeded.
  Future<bool> confirm(DeleteConfirmArgs args) async {
    state = const DeleteConfirmState(deleting: true);
    try {
      await args.onConfirm();
      await ref.read(navigatorProvider).pushActionResult(args.successResult);
      await args.onDeleted();
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
    }
  }
}

final deleteConfirmControllerProvider =
    NotifierProvider<DeleteConfirmController, DeleteConfirmState>(
      DeleteConfirmController.new,
    );
