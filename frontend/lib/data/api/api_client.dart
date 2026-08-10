import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@singleton
class ApiClient {
  /// [dio] is injectable for tests; production uses the default client.
  ApiClient({@ignoreParam Dio? dio}) : _dio = dio ?? _defaultDio();

  static const String _defaultBase = 'http://127.0.0.1:8000/api';

  static Dio _defaultDio() {
    return Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _defaultBase,
        ),
      ),
    )..interceptors.add(ChuckerDioInterceptor());
  }

  final Dio _dio;

  Dio get dio => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic data) parse,
  }) async {
    final resp = await _dio.get(path, queryParameters: query);
    return parse(resp.data);
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    ProgressCallback? onSendProgress,
    required T Function(dynamic data) parse,
  }) async {
    final resp = await _dio.post(path, data: data, onSendProgress: onSendProgress);
    return parse(resp.data);
  }

  Future<void> delete(String path) async {
    await _dio.delete(path);
  }
}
