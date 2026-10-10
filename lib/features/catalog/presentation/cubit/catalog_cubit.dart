import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/catalog_repository.dart';

class CatalogState {
  const CatalogState({
    this.foods = const [],
    this.loading = false,
    this.loadingMore = false,
    this.loaded = false,
    this.hasMore = false,
    this.error,
    this.moreError,
  });

  final List<FoodSummary> foods;
  final bool loading;
  final bool loadingMore;
  final bool loaded;
  final bool hasMore;
  final String? error;
  final String? moreError;
}

class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository) : super(const CatalogState());

  final CatalogRepository _repository;
  int _nextPage = 0;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    _nextPage = 0;
    emit(CatalogState(foods: state.foods, loading: true, loaded: state.loaded));
    try {
      final result = await _repository.list(0);
      if (isClosed || generation != _generation) return;
      _nextPage = 1;
      emit(
        CatalogState(
          foods: result.foods,
          loaded: true,
          hasMore: _nextPage < result.totalPages,
        ),
      );
    } on CatalogFailure catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        CatalogState(
          foods: state.foods,
          loaded: state.loaded,
          hasMore: state.hasMore,
          error: error.message,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.loaded ||
        !state.hasMore ||
        state.loading ||
        state.loadingMore ||
        state.moreError != null) {
      return;
    }
    final generation = _generation;
    final page = _nextPage;
    emit(
      CatalogState(
        foods: state.foods,
        loaded: true,
        hasMore: true,
        loadingMore: true,
      ),
    );
    try {
      final result = await _repository.list(page);
      if (isClosed || generation != _generation) return;
      _nextPage = page + 1;
      final seen = state.foods.map((food) => food.id).toSet();
      emit(
        CatalogState(
          foods: [
            ...state.foods,
            ...result.foods.where((food) => seen.add(food.id)),
          ],
          loaded: true,
          hasMore: _nextPage < result.totalPages,
        ),
      );
    } on CatalogFailure catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        CatalogState(
          foods: state.foods,
          loaded: true,
          hasMore: true,
          moreError: error.message,
        ),
      );
    }
  }

  void retryMore() {
    if (state.moreError == null) return;
    emit(
      CatalogState(
        foods: state.foods,
        loaded: state.loaded,
        hasMore: state.hasMore,
      ),
    );
    loadMore();
  }
}
