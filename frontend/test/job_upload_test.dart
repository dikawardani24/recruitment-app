import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/data/api/api_client.dart';
import 'package:ai_ats/data/data_sources/job_api_data_source.dart';
import 'package:ai_ats/data/repositories/job_repository_impl.dart';
import 'package:ai_ats/domain/models/upload_file.dart';

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{"job":{"job_id":"job-1","title":"Backend",'
      '"description":"Build","status":"open","created_at":"now"}}',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('uploads a web JD from picker bytes when its path is null', () async {
    final picked = PlatformFile(
      name: 'description.txt',
      size: 5,
      bytes: Uint8List.fromList([66, 117, 105, 108, 100]),
    );
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = JobRepositoryImpl(JobApiDataSource(ApiClient(dio: dio)));

    final job = await repository.createJob(
      title: 'Backend',
      description: 'Build',
      jdFile: UploadFile(name: picked.name, bytes: picked.bytes!),
    );

    expect(picked.path, isNull);
    expect(job.id, 'job-1');
    final form = adapter.request!.data as FormData;
    expect(form.files.single.key, 'jd_file');
    expect(form.files.single.value.filename, 'description.txt');
  });
}
