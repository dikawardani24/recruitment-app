import 'dart:io';

import 'package:dio/dio.dart';

import 'models.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const String _defaultBase = 'http://127.0.0.1:8000/api';
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: _defaultBase,
      ),
    ),
  );

  Future<List<Job>> listJobs() async {
    final resp = await _dio.get('/jobs');
    final data = resp.data as Map<String, dynamic>;
    final jobs = (data['jobs'] as List?) ?? [];
    return jobs
        .map((e) => Job.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Job> createJob({
    required String title,
    required String description,
    File? jdFile,
    String? jdFileName,
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('title', title));
    form.fields.add(MapEntry('description', description));
    if (jdFile != null) {
      form.files.add(
        MapEntry(
          'jd_file',
          await MultipartFile.fromFile(
            jdFile.path,
            filename: jdFileName ?? jdFile.path.split('/').last,
          ),
        ),
      );
    }
    final resp = await _dio.post('/jobs', data: form);
    final job = (resp.data as Map<String, dynamic>)['job'];
    return Job.fromJson(job as Map<String, dynamic>);
  }

  Future<Job> getJob(String jobId) async {
    final resp = await _dio.get('/jobs/$jobId');
    final job = (resp.data as Map<String, dynamic>)['job'];
    return Job.fromJson(job as Map<String, dynamic>);
  }

  Future<List<CandidateResult>> uploadCvs(
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
    final resp = await _dio.post('/jobs/$jobId/cvs', data: form);
    final results = (resp.data as Map<String, dynamic>)['results'] as List;
    return results
        .map((e) => CandidateResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CandidateResult>> listCvs(String jobId) async {
    final resp = await _dio.get('/jobs/$jobId/cvs');
    final results = (resp.data as Map<String, dynamic>)['results'] as List;
    return results
        .map((e) => CandidateResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RankResponse> rankJob(String jobId) async {
    final resp = await _dio.post('/jobs/$jobId/rank');
    final data = resp.data as Map<String, dynamic>;
    final results = (data['results'] as List)
        .map((e) => CandidateResult.fromJson(e as Map<String, dynamic>))
        .toList();
    return RankResponse(
      source: data['source'] as String? ?? 'rules',
      results: results,
    );
  }

  Future<List<CandidateResult>> getRankings(String jobId) async {
    final resp = await _dio.get('/jobs/$jobId/rankings');
    final results = (resp.data as Map<String, dynamic>)['results'] as List;
    return results
        .map((e) => CandidateResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class RankResponse {
  final String source;
  final List<CandidateResult> results;

  const RankResponse({required this.source, required this.results});
}
