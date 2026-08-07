import 'dart:io';

import '../models/job.dart';
import '../models/job_page.dart';

abstract class JobRepository {
  Future<JobPage> listJobs({int page = 1, int limit = 20});

  Future<Job> createJob({
    required String title,
    required String description,
    File? jdFile,
    String? jdFileName,
  });

  Future<Job> getJob(String jobId);

  Future<void> deleteJob(String jobId);
}
