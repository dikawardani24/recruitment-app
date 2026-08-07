// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import 'data/api/api_client.dart' as _i625;
import 'data/data_sources/candidate_api_data_source.dart' as _i603;
import 'data/data_sources/job_api_data_source.dart' as _i188;
import 'data/repositories/candidate_repository_impl.dart' as _i1019;
import 'data/repositories/job_repository_impl.dart' as _i271;
import 'domain/repositories/candidate_repository.dart' as _i1049;
import 'domain/repositories/job_repository.dart' as _i324;
import 'domain/usecases/create_job.dart' as _i146;
import 'domain/usecases/delete_candidate.dart' as _i17;
import 'domain/usecases/delete_job.dart' as _i34;
import 'domain/usecases/get_job.dart' as _i621;
import 'domain/usecases/get_rankings.dart' as _i692;
import 'domain/usecases/list_cvs.dart' as _i542;
import 'domain/usecases/list_jobs.dart' as _i111;
import 'domain/usecases/rank_cv.dart' as _i51;
import 'domain/usecases/rank_job.dart' as _i404;
import 'domain/usecases/upload_cvs.dart' as _i364;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt $setupDependencies({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.singleton<_i625.ApiClient>(() => _i625.ApiClient());
    gh.factory<_i603.CandidateApiDataSource>(
      () => _i603.CandidateApiDataSource(gh<_i625.ApiClient>()),
    );
    gh.factory<_i188.JobApiDataSource>(
      () => _i188.JobApiDataSource(gh<_i625.ApiClient>()),
    );
    gh.factory<_i1049.CandidateRepository>(
      () => _i1019.CandidateRepositoryImpl(gh<_i603.CandidateApiDataSource>()),
    );
    gh.factory<_i17.DeleteCandidate>(
      () => _i17.DeleteCandidate(gh<_i1049.CandidateRepository>()),
    );
    gh.factory<_i692.GetRankings>(
      () => _i692.GetRankings(gh<_i1049.CandidateRepository>()),
    );
    gh.factory<_i542.ListCvs>(
      () => _i542.ListCvs(gh<_i1049.CandidateRepository>()),
    );
    gh.factory<_i51.RankCv>(
      () => _i51.RankCv(gh<_i1049.CandidateRepository>()),
    );
    gh.factory<_i404.RankJob>(
      () => _i404.RankJob(gh<_i1049.CandidateRepository>()),
    );
    gh.factory<_i364.UploadCvs>(
      () => _i364.UploadCvs(gh<_i1049.CandidateRepository>()),
    );
    gh.factory<_i324.JobRepository>(
      () => _i271.JobRepositoryImpl(gh<_i188.JobApiDataSource>()),
    );
    gh.factory<_i146.CreateJob>(
      () => _i146.CreateJob(gh<_i324.JobRepository>()),
    );
    gh.factory<_i34.DeleteJob>(() => _i34.DeleteJob(gh<_i324.JobRepository>()));
    gh.factory<_i621.GetJob>(() => _i621.GetJob(gh<_i324.JobRepository>()));
    gh.factory<_i111.ListJobs>(() => _i111.ListJobs(gh<_i324.JobRepository>()));
    return this;
  }
}
