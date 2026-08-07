import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@singleton
class ApiClient {
  ApiClient();

  static const String _defaultBase = 'http://127.0.0.1:8000/api';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: _defaultBase,
      ),
    ),
  )..interceptors.add(ChuckerDioInterceptor());

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
    required T Function(dynamic data) parse,
  }) async {
    final resp = await _dio.post(path, data: data);
    return parse(resp.data);
  }

  Future<void> delete(String path) async {
    await _dio.delete(path);
  }
}
