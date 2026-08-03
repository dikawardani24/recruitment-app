import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di.dart';
import '../domain/search_repository.dart';
import '../presentation/search_cubit.dart';
import 'ranking_list.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchCubit(getIt<SearchRepository>()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Candidate Search')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SearchBar(),
              const SizedBox(height: 16),
              Expanded(
                child: BlocBuilder<SearchCubit, SearchState>(
                  builder: (context, state) => switch (state) {
                    SearchIdle() => const Center(child: Text('Ask a natural-language query')),
                    SearchLoading() => const Center(child: CircularProgressIndicator()),
                    SearchError(:final message) => Center(child: Text(message)),
                    SearchLoaded(:final results) => RankingList(results: results),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchBar extends StatefulWidget {
  const SearchBar({super.key});

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        if (value.trim().isNotEmpty) {
          context.read<SearchCubit>().search(value.trim());
        }
      },
      decoration: InputDecoration(
        hintText: 'Find Senior Flutter Developers with banking experience',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              context.read<SearchCubit>().search(_controller.text.trim());
            }
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
