import '../models/unified_search_result.dart';

abstract class SearchRepository {
  Future<UnifiedSearchResult> unifiedSearch({
    required String keyword,
    int limit = 5,
  });
}
