import 'package:flutter_bloc/flutter_bloc.dart';

import '../../ranking/domain/ranking_models.dart';
import '../domain/search_repository.dart';

sealed class SearchState {
  const SearchState();
}

class SearchIdle extends SearchState {
  const SearchIdle();
}

class SearchLoading extends SearchState {
  const SearchLoading();
}

class SearchLoaded extends SearchState {
  const SearchLoaded(this.results);
  final List<RankedCandidate> results;
}

class SearchError extends SearchState {
  const SearchError(this.message);
  final String message;
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._repository) : super(const SearchIdle());

  final SearchRepository _repository;

  Future<void> search(String query) async {
    emit(const SearchLoading());
    try {
      final results = await _repository.query(query);
      emit(SearchLoaded(results));
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }
}
