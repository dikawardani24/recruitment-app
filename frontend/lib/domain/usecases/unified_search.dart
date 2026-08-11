import 'package:injectable/injectable.dart';

import '../models/unified_search_result.dart';
import '../repositories/search_repository.dart';

@injectable
class UnifiedSearch {
  UnifiedSearch(this._repository);

  final SearchRepository _repository;

  Future<UnifiedSearchResult> call({
    required String keyword,
    int limit = 5,
  }) {
    return _repository.unifiedSearch(keyword: keyword, limit: limit);
  }
}
