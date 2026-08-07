import 'dart:io';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../api/api_client.dart';
import '../api/api_paths.dart';
import '../api/mappers.dart';
import '../api/response_models.dart';

@Injectable()
class CandidateApiDataSource {
  CandidateApiDataSource(this._client);

  final ApiClient _client;

  Future<List<CandidateResponse>> uploadCvs(
    String jobId,
    List<File> files,
  ) async {
    final form = FormData();
    for (final file in files) {
      form.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          ),
        ),
      );
    }
    return _client.post(
      ApiPaths.cvs(jobId),
      data: form,
      parse: _resultList,
    );
  }

  Future<List<CandidateResponse>> listCvs(String jobId) {
    return _client.get(ApiPaths.cvs(jobId), parse: _resultList);
  }

  Future<RankResponseDto> rankJob(String jobId) {
    return _client.post(
      ApiPaths.rank(jobId),
      parse: (data) =>
          RankResponseMapper.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<CandidateResponse> rankCv(String jobId, String cvId) {
    return _client.post(
      ApiPaths.cvRank(jobId, cvId),
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

  static List<CandidateResponse> _resultList(dynamic data) {
    final results = (data as Map<String, dynamic>)['results'] as List;
    return results
        .map((e) => CandidateResponseMapper.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
