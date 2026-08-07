import 'package:injectable/injectable.dart';
import '../models/job_page.dart';
import '../repositories/job_repository.dart';

@Injectable()
class ListJobs {
  const ListJobs(this._repository);

  final JobRepository _repository;

  Future<JobPage> call({int page = 1, int limit = 20}) =>
      _repository.listJobs(page: page, limit: limit);
}
