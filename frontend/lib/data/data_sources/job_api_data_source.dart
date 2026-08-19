import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../api/api_client.dart';
import '../api/api_paths.dart';
import '../api/mappers.dart';
import '../api/response_models.dart';
import '../../domain/models/upload_file.dart';

@Injectable()
class JobApiDataSource {
  JobApiDataSource(this._client);

  final ApiClient _client;

  Future<JobPageResponse> listJobs({int page = 1, int limit = 20}) {
    return _client.get(
      ApiPaths.jobs,
      query: {'page': page, 'limit': limit},
      parse: (data) => JobPageResponseMapper.fromJson(
        data as Map<String, dynamic>,
        fallbackPage: page,
        fallbackLimit: limit,
      ),
    );
  }

  Future<JobPageResponse> searchJobs({
    required String keyword,
    int page = 1,
    int limit = 20,
  }) {
    return _client.get(
      ApiPaths.searchJobs,
      query: {'keyword': keyword, 'page': page, 'limit': limit},
      parse: (data) => JobPageResponseMapper.fromJson(
        data as Map<String, dynamic>,
        fallbackPage: page,
        fallbackLimit: limit,
      ),
    );
  }

  Future<JobResponse> createJob({
    required String title,
    required String description,
    UploadFile? jdFile,
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('title', title));
    form.fields.add(MapEntry('description', description));
    if (jdFile != null) {
      form.files.add(
        MapEntry(
          'jd_file',
          MultipartFile.fromBytes(jdFile.bytes, filename: jdFile.name),
        ),
      );
    }
    return _client.post(
      ApiPaths.jobs,
      data: form,
      parse: (data) => JobResponseMapper.fromJson(
        (data as Map<String, dynamic>)['job'] as Map<String, dynamic>,
      ),
    );
  }

  Future<JobResponse> getJob(String jobId) {
    return _client.get(
      ApiPaths.job(jobId),
      parse: (data) => JobResponseMapper.fromJson(
        (data as Map<String, dynamic>)['job'] as Map<String, dynamic>,
      ),
    );
  }

  Future<void> deleteJob(String jobId) {
    return _client.delete(ApiPaths.job(jobId));
  }
}
