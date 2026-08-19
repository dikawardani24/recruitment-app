import '../models/job.dart';
import '../models/job_page.dart';
import '../models/upload_file.dart';

abstract class JobRepository {
  Future<JobPage> listJobs({int page = 1, int limit = 20});

  Future<JobPage> searchJobs({
    required String keyword,
    int page = 1,
    int limit = 20,
  });

  Future<Job> createJob({
    required String title,
    required String description,
    UploadFile? jdFile,
  });

  Future<Job> getJob(String jobId);

  Future<void> deleteJob(String jobId);
}
