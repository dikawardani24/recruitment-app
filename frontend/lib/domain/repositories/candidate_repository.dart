import 'dart:io';

import '../models/candidate_result.dart';
import '../models/rank_response.dart';

abstract class CandidateRepository {
  Future<List<CandidateResult>> uploadCvs(String jobId, List<File> files);

  Future<List<CandidateResult>> listCvs(String jobId);

  Future<RankResponse> rankJob(String jobId);

  Future<CandidateResult> rankCv(String jobId, String cvId);

  Future<List<CandidateResult>> getRankings(String jobId);

  Future<void> deleteCandidate(String jobId, String cvId);
}
