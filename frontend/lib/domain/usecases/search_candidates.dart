import 'package:injectable/injectable.dart';

import '../models/candidate_page.dart';
import '../repositories/candidate_repository.dart';

@injectable
class SearchCandidates {
  SearchCandidates(this.cvRepo);

  final CandidateRepository cvRepo;

  Future<CandidatePage> call({
    required String keyword,
    int page = 1,
    int limit = 20,
  }) {
    return cvRepo.searchCandidates(
      keyword: keyword,
      page: page,
      limit: limit,
    );
  }
}
