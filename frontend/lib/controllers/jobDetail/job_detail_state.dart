/// UI-busy state for the job detail screen, owned here instead of via local
/// hooks so the action methods can live outside the widget.
class JobDetailState {
  final bool busy;
  final String? loadingMessage;

  const JobDetailState({this.busy = false, this.loadingMessage});
}
