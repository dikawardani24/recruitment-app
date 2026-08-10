/// UI-busy state for the job form screen.
class JobFormState {
  final bool submitting;
  final String? loadingMessage;

  const JobFormState({this.submitting = false, this.loadingMessage});
}
