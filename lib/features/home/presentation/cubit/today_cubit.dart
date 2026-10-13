import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/today_repository.dart';

class TodayState {
  const TodayState({
    this.data,
    this.loading = false,
    this.error,
    this.savingMealId,
    this.mealError,
  });

  final TodayData? data;
  final bool loading;
  final String? error;
  final String? savingMealId;
  final String? mealError;
}

class TodayCubit extends Cubit<TodayState> {
  TodayCubit(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const TodayState());

  final TodayRepository _repository;
  final DateTime Function() _now;
  int _loadGeneration = 0;

  Future<void> load({DateTime? date, bool clearData = false}) async {
    final generation = ++_loadGeneration;
    emit(TodayState(data: clearData ? null : state.data, loading: true));
    try {
      final data = await _repository.load(date ?? _now());
      if (isClosed || generation != _loadGeneration) return;
      emit(TodayState(data: data));
    } on TodayFailure catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        TodayState(data: clearData ? null : state.data, error: error.message),
      );
    }
  }

  Future<bool> record(TodayMeal meal, CompletionType type) async {
    if (state.savingMealId != null) return false;
    emit(TodayState(data: state.data, savingMealId: meal.id));
    try {
      final event = await _repository.record(meal, type);
      if (isClosed) return true;
      final current = state.data;
      if (current != null) {
        emit(
          TodayState(
            data: TodayData(
              meals: current.meals,
              latestEvents: {...current.latestEvents, meal.id: event},
              availablePeriods: current.availablePeriods,
              summary: current.summary,
            ),
          ),
        );
      }
      return true;
    } on TodayFailure catch (error) {
      if (isClosed) return false;
      emit(TodayState(data: state.data, mealError: error.message));
      return false;
    }
  }
}
