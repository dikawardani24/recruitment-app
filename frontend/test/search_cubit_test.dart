import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:ai_ats/features/ranking/domain/ranking_models.dart';
import 'package:ai_ats/features/search/domain/search_repository.dart';
import 'package:ai_ats/features/search/presentation/search_cubit.dart';

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository(this._results);
  final List<RankedCandidate> _results;

  @override
  Future<List<RankedCandidate>> query(String query, {int topK = 20}) async => _results;
}

void main() {
  blocTest<SearchCubit, SearchState>(
    'emits loading then loaded',
    build: () => SearchCubit(_FakeSearchRepository([])),
    act: (cubit) => cubit.search('flutter'),
    expect: () => [isA<SearchLoading>(), isA<SearchLoaded>()],
  );

  test('ranked candidate default bucket is alternative', () {
    final candidate = RankedCandidate.fromJson(<String, dynamic>{
      'candidate_id': 'x',
      'bucket': 'unknown_bucket',
      'scores': <String, dynamic>{},
    });
    expect(candidate.bucket, RankingBucket.alternative);
  });
}
