import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  /// User-friendly message mapped from backend error codes (doc 03 §9).
  String get userMessage {
    switch (statusCode) {
      case 401:
        return 'Your session has expired. Please log in again.';
      case 429:
        return 'Too many requests. Please wait a moment and retry.';
      case 503:
        return 'The service is temporarily unavailable. Try again shortly.';
      default:
        return message.isNotEmpty ? message : 'Something went wrong. Please retry.';
    }
  }
}

class ApiExceptionMapper {
  static ApiException from(DioException error) {
    final data = error.response?.data;
    final detail = data is Map ? data['detail']?.toString() ?? '' : '';
    return ApiException(
      detail,
      statusCode: error.response?.statusCode,
      cause: error,
    );
  }
}
