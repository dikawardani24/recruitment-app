import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/data/api/api_client.dart';
import 'package:ai_ats/data/data_sources/candidate_api_data_source.dart';
import 'package:ai_ats/data/repositories/candidate_repository_impl.dart';
import 'package:ai_ats/domain/models/candidate_result.dart';
import 'package:ai_ats/domain/models/import_result.dart';
import 'package:ai_ats/domain/models/rank_response.dart';
import 'package:ai_ats/domain/repositories/candidate_repository.dart';
import 'package:ai_ats/domain/usecases/upload_cvs.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._responses);

  final Map<String, String> _responses; // key: 'POST <path>' / 'GET <path>'
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final uri = options.uri;
    final path = uri.path;
    final key = '${options.method} $path';
    final body = _responses[key];
    if (body == null) {
      return ResponseBody.fromString('{"detail":"not_found"}', 404,
          headers: {'content-type': ['application/json']});
    }
    return ResponseBody.fromString(body, 200,
        headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

class _FakeApiClient {
  static ApiClient routed(Map<String, String> responses) {
    final dio = Dio()..httpClientAdapter = _FakeAdapter(responses);
    return ApiClient(dio: dio);
  }
}

void main() {
  group('uploadCvBatch', () {
    test('posts files and import_id, parses ImportResponse', () async {
      final tmp = Directory.systemTemp.createTempSync('upload_test');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final f1 = File('${tmp.path}/a.txt')..writeAsStringSync('CV A');
      final f2 = File('${tmp.path}/b.txt')..writeAsStringSync('CV B');

      final client = _FakeApiClient.routed({
        'POST /jobs/job-1/candidates/import':
            '{"import_id":"imp-1","job_id":"job-1","status":"submitted",'
            '"total_files":2,"batch_files":2}',
      });
      final ds = CandidateApiDataSource(client);
      final repo = CandidateRepositoryImpl(ds);

      final resp = await repo.uploadCvBatch(
        'job-1',
        importId: 'imp-x',
        files: [f1, f2],
      );

      expect(resp.importId, 'imp-1');
      expect(resp.status, 'submitted');
      expect(resp.batchFiles, 2);
      expect(resp.totalFiles, 2);
      expect(resp, isA<ImportResponse>());

      final adapter = client.dio.httpClientAdapter as _FakeAdapter;
      final sent = adapter.requests.single;
      expect(sent.path, '/jobs/job-1/candidates/import');
      final form = sent.data as FormData;
      expect(form.fields.map((f) => f.key), contains('import_id'));
      expect(form.fields.firstWhere((f) => f.key == 'import_id').value, 'imp-x');
      expect(form.files.length, 2);
    });

    test('creates a fresh import when importId is omitted', () async {
      final tmp = Directory.systemTemp.createTempSync('upload_test2');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final f1 = File('${tmp.path}/a.txt')..writeAsStringSync('CV A');

      final client = _FakeApiClient.routed({
        'POST /jobs/job-1/candidates/import':
            '{"import_id":"imp-new","job_id":"job-1","status":"submitted",'
            '"total_files":1,"batch_files":1}',
      });
      final repo = CandidateRepositoryImpl(CandidateApiDataSource(client));

      final resp = await repo.uploadCvBatch('job-1', files: [f1]);
      expect(resp.importId, 'imp-new');
    });

    test('getImportStatus parses the status endpoint', () async {
      final client = _FakeApiClient.routed({
        'GET /jobs/job-1/imports/imp-1':
            '{"import_id":"imp-1","job_id":"job-1","status":"processing",'
            '"total":100,"uploaded":80,"processed":67,"failed":2,'
            '"pending":31,"created_at":null,"completed_at":null}',
      });
      final repo = CandidateRepositoryImpl(CandidateApiDataSource(client));

      final status = await repo.getImportStatus('job-1', 'imp-1');
      expect(status.status, 'processing');
      expect(status.total, 100);
      expect(status.processed, 67);
      expect(status.failed, 2);
      expect(status.pending, 31);
      expect(status.isTerminal, isFalse);
    });
  });

  group('UploadCvs use case', () {
    test('delegates to the repository', () async {
      final calls = <String?>[];
      final useCase = UploadCvs(_FakeRepository((importId, _) async {
        calls.add(importId);
        return const ImportResponse(
          importId: 'imp-1',
          jobId: 'job-1',
          status: 'submitted',
          totalFiles: 1,
          batchFiles: 1,
        );
      }));

      final tmp = Directory.systemTemp.createTempSync('upload_test3');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final f1 = File('${tmp.path}/a.txt')..writeAsStringSync('CV A');

      final resp = await useCase('job-1', importId: 'imp-9', files: [f1]);
      expect(resp.importId, 'imp-1');
      expect(calls.single, 'imp-9');
    });
  });
}

class _FakeRepository implements CandidateRepository {
  _FakeRepository(this._onUpload);

  final Future<ImportResponse> Function(String? importId, List<File> files)
      _onUpload;

  @override
  Future<ImportResponse> uploadCvBatch(
    String jobId, {
    String? importId,
    required List<File> files,
    ProgressCallback? onSendProgress,
  }) =>
      _onUpload(importId, files);

  @override
  Future<ImportStatus> getImportStatus(String jobId, String importId) {
    throw UnimplementedError();
  }

  @override
  Future<List<CandidateResult>> listCvs(String jobId) {
    throw UnimplementedError();
  }

  @override
  Future<RankResponse> rankJob(String jobId) {
    throw UnimplementedError();
  }

  @override
  Future<CandidateResult> rankCv(String jobId, String cvId) {
    throw UnimplementedError();
  }

  @override
  Future<List<CandidateResult>> getRankings(String jobId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCandidate(String jobId, String cvId) {
    throw UnimplementedError();
  }
}
