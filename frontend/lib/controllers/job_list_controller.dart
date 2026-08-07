import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Owns the job list actions. The list has no busy/loading UI state, so this
/// is a plain controller instead of a [Notifier].
class JobListController {
  JobListController(this._ref);

  final Ref _ref;

  Future<void> refresh() {
    return _ref.read(jobsProvider.notifier).refresh();
  }

  Future<void> loadMore() {
    return _ref.read(jobsProvider.notifier).loadMore();
  }
}

final jobListControllerProvider =
    Provider<JobListController>((ref) => JobListController(ref));
