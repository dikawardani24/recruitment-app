import 'package:injectable/injectable.dart';

import '../models/job_page.dart';
import '../repositories/job_repository.dart';

@Injectable()
class SearchJobs {
  const SearchJobs(this._repository);

  final JobRepository _repository;

  Future<JobPage> call({
    required String keyword,
    int page = 1,
    int limit = 20,
  }) =>
      _repository.searchJobs(keyword: keyword, page: page, limit: limit);
}
