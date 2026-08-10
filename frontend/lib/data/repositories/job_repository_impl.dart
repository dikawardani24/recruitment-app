import 'dart:io';

import 'package:injectable/injectable.dart';

import '../../domain/models/job.dart';
import '../../domain/models/job_page.dart';
import '../../domain/models/job_requirements.dart';
import '../../domain/repositories/job_repository.dart';
import '../api/response_models.dart';
import '../data_sources/job_api_data_source.dart';

@Injectable(as: JobRepository)
class JobRepositoryImpl implements JobRepository {
  JobRepositoryImpl(this._dataSource);

  final JobApiDataSource _dataSource;

  @override
  Future<JobPage> listJobs({int page = 1, int limit = 20}) async {
    final dto = await _dataSource.listJobs(page: page, limit: limit);
    return JobPage(
      jobs: dto.jobs.map(_toJob).toList(),
      page: dto.page,
      hasMore: dto.hasMore,
    );
  }

  @override
  Future<JobPage> searchJobs({
    required String keyword,
    int page = 1,
    int limit = 20,
  }) async {
    final dto = await _dataSource.searchJobs(
      keyword: keyword,
      page: page,
      limit: limit,
    );
    return JobPage(
      jobs: dto.jobs.map(_toJob).toList(),
      page: dto.page,
      hasMore: dto.hasMore,
    );
  }

  @override
  Future<Job> createJob({
    required String title,
    required String description,
    File? jdFile,
    String? jdFileName,
  }) async {
    final dto = await _dataSource.createJob(
      title: title,
      description: description,
      jdFile: jdFile,
      jdFileName: jdFileName,
    );
    return _toJob(dto);
  }

  @override
  Future<Job> getJob(String jobId) async {
    return _toJob(await _dataSource.getJob(jobId));
  }

  @override
  Future<void> deleteJob(String jobId) => _dataSource.deleteJob(jobId);

  Job _toJob(JobResponse dto) {
    return Job(
      id: dto.jobId,
      title: dto.title,
      description: dto.description,
      status: dto.status,
      createdAt: dto.createdAt,
      candidateCount: dto.cvCount,
      requirements: _toRequirements(dto.requirements),
    );
  }

  JobRequirements? _toRequirements(JobRequirementsResponse? dto) {
    if (dto == null) return null;
    return JobRequirements(
      title: dto.title,
      requiredSkills: dto.requiredSkills,
      preferredSkills: dto.preferredSkills,
      minYears: dto.minYears,
      education: dto.education,
      certifications: dto.certifications,
      responsibilities: dto.responsibilities,
    );
  }
}
