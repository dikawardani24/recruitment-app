import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../api/api_client.dart';
import '../api/api_paths.dart';
import '../api/mappers.dart';
import '../api/response_models.dart';
import '../../domain/models/upload_file.dart';

@Injectable()
class CandidateApiDataSource {
  CandidateApiDataSource(this._client);

  final ApiClient _client;

  Future<ImportResponseDto> uploadCvBatch(
    String jobId, {
    String? importId,
    required List<UploadFile> files,
    ProgressCallback? onSendProgress,
  }) async {
    final form = FormData();
    if (importId != null) {
      form.fields.add(MapEntry('import_id', importId));
    }
    for (final file in files) {
      form.files.add(
        MapEntry(
          'files',
          MultipartFile.fromBytes(file.bytes, filename: file.name),
        ),
      );
    }
    return _client.post(
      ApiPaths.candidateImport(jobId),
      data: form,
      onSendProgress: onSendProgress,
      parse: (data) =>
          ImportResponseMapper.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<ImportStatusDto> getImportStatus(String jobId, String importId) {
    return _client.get(
      ApiPaths.importStatus(jobId, importId),
      parse: (data) =>
          ImportStatusMapper.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<CandidateResponse>> listCvs(String jobId) {
    return _client.get(ApiPaths.cvs(jobId), parse: _resultList);
  }

  Future<RankResponseDto> rankJob(String jobId, {String? apiKey}) {
    return _client.post(
      ApiPaths.rank(jobId),
      data: {'api_key': apiKey},
      parse: (data) =>
          RankResponseMapper.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<CandidateResponse> rankCv(String jobId, String cvId, {String? apiKey}) {
    return _client.post(
      ApiPaths.cvRank(jobId, cvId),
      data: {'api_key': apiKey},
      parse: (data) => CandidateResponseMapper.fromJson(
        (data as Map<String, dynamic>)['result'] as Map<String, dynamic>,
      ),
    );
  }

  Future<List<CandidateResponse>> getRankings(String jobId) {
    return _client.get(ApiPaths.rankings(jobId), parse: _resultList);
  }

  Future<void> deleteCandidate(String jobId, String cvId) {
    return _client.delete(ApiPaths.cv(jobId, cvId));
  }

  Future<CandidatePageResponse> searchCandidates({
    required String keyword,
    required int page,
    required int limit,
  }) {
    return _client.get(
      ApiPaths.searchCandidates,
      query: {'keyword': keyword, 'page': page, 'limit': limit},
      parse: (data) => CandidatePageResponseMapper.fromJson(
        data as Map<String, dynamic>,
        fallbackPage: page,
        fallbackLimit: limit,
      ),
    );
  }

  static List<CandidateResponse> _resultList(dynamic data) {
    final results = (data as Map<String, dynamic>)['results'] as List;
    return results
        .map((e) => CandidateResponseMapper.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
