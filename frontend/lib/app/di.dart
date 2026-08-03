import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../features/search/data/search_repository_impl.dart';
import '../features/search/domain/search_repository.dart';

final getIt = GetIt.instance;

class Environment {
  const Environment._(this.apiBaseUrl);
  final String apiBaseUrl;

  static const dev = Environment._('http://localhost:8000/v1');
  static const prod = Environment._('https://api.ats.example.com/v1');
}

Future<void> initDi(Environment env) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  getIt
    ..registerLazySingleton<Dio>(() => dio)
    ..registerLazySingleton<SearchRepository>(
      () => SearchRepositoryImpl(getIt<Dio>()),
    );
}
