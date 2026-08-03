import '../../ranking/domain/ranking_models.dart';

abstract interface class SearchRepository {
  Future<List<RankedCandidate>> query(String query, {int topK = 20});
}
