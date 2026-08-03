import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../ranking/domain/ranking_models.dart';
import '../domain/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<RankedCandidate>> query(String query, {int topK = 20}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/search/query',
        data: {'query': query, 'top_k': topK},
      );
      final results = response.data?['results'] as List? ?? [];
      return results
          .map((e) => RankedCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiExceptionMapper.from(e);
    }
  }
}
