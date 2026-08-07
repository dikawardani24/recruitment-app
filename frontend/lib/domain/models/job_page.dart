import 'job.dart';

class JobPage {
  final List<Job> jobs;
  final int page;
  final bool hasMore;

  const JobPage({required this.jobs, required this.page, required this.hasMore});
}
