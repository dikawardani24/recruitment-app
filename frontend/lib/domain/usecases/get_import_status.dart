import 'package:injectable/injectable.dart';

import '../models/import_result.dart';
import '../repositories/candidate_repository.dart';

@Injectable()
class GetImportStatus {
  const GetImportStatus(this._repository);

  final CandidateRepository _repository;

  Future<ImportStatus> call(String jobId, String importId) =>
      _repository.getImportStatus(jobId, importId);
}
