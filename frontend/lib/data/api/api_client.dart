import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@singleton
class ApiClient {
  /// [dio] is injectable for tests; production uses the default client.
  ApiClient({@ignoreParam Dio? dio}) : _dio = dio ?? _defaultDio();

  static const String _defaultBase = 'https://recruitment-app-z4kg.onrender.com/api';

  static Dio _defaultDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _defaultBase,
        ),
      ),
    );
    dio.interceptors.add(_ChuckerStreamSafeInterceptor());
    return dio;
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
    final resp = await _dio.post(
      path,
      data: data,
      onSendProgress: onSendProgress,
    );
    return parse(resp.data);
  }

  Future<void> delete(String path) async {
    await _dio.delete(path);
  }

  /// POST returning the raw response body as a byte stream (e.g. SSE).
  Stream<List<int>> postStream(String path, {Object? data}) async* {
    final resp = await _dio.post<ResponseBody>(
      path,
      data: data,
      options: Options(responseType: ResponseType.stream),
    );
    final body = resp.data;
    if (body == null) return;
    yield* body.stream;
  }
}

/// Wraps [ChuckerDioInterceptor] but skips stream requests. Chucker tries to
/// [jsonEncode] every response body, which throws on a streamed [ResponseBody]
/// (no [toJson]) and aborts the call before Dio delivers it.
class _ChuckerStreamSafeInterceptor extends Interceptor {
  final _chucker = ChuckerDioInterceptor();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (options.responseType == ResponseType.stream) {
      handler.next(options);
      return;
    }
    _chucker.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.requestOptions.responseType == ResponseType.stream) {
      handler.next(response);
      return;
    }
    _chucker.onResponse(response, handler);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (err.requestOptions.responseType == ResponseType.stream) {
      handler.next(err);
      return;
    }
    _chucker.onError(err, handler);
  }
}
