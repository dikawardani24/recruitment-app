import 'package:injectable/injectable.dart';

import '../api/api_client.dart';
import '../api/api_paths.dart';
import '../api/mappers.dart';
import '../api/response_models.dart';

@Injectable()
class SearchApiDataSource {
  SearchApiDataSource(this._client);

  final ApiClient _client;

  Future<UnifiedSearchResponse> unifiedSearch({
    required String keyword,
    required int limit,
  }) {
    return _client.get(
      ApiPaths.unifiedSearch,
      query: {
        'keyword': keyword,
        'limit': limit,
      },
      parse: (data) => UnifiedSearchResponseMapper.fromJson(data as Map<String, dynamic>),
    );
  }
}
