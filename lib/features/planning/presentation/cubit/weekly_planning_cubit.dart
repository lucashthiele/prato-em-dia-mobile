import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/weekly_plan.dart';
import '../../domain/weekly_planning_repository.dart';

class WeeklyPlanningState {
  const WeeklyPlanningState({
    this.plans = const [],
    this.selected,
    this.preference,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.notice,
  });

  final List<WeeklyPlan> plans;
  final WeeklyPlan? selected;
  final WeeklyPlanningPreference? preference;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? notice;

  WeeklyPlanningState copyWith({
    List<WeeklyPlan>? plans,
    WeeklyPlan? selected,
    bool clearSelected = false,
    WeeklyPlanningPreference? preference,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? notice,
  }) => WeeklyPlanningState(
    plans: plans ?? this.plans,
    selected: clearSelected ? null : selected ?? this.selected,
    preference: preference ?? this.preference,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    error: error,
    notice: notice,
  );
}

class WeeklyPlanningCubit extends Cubit<WeeklyPlanningState> {
  WeeklyPlanningCubit(this._repository) : super(const WeeklyPlanningState());

  final WeeklyPlanningRepository _repository;

  void _safeEmit(WeeklyPlanningState next) {
    if (!isClosed) emit(next);
  }

  Future<void> load() async {
    if (state.isLoading || state.isSaving) return;
    _safeEmit(state.copyWith(isLoading: true));
    try {
      final plans = await _repository.list();
      WeeklyPlanningPreference? preference;
      String? preferenceError;
      try {
        preference = await _repository.getPreference();
      } on PlanningFailure catch (error) {
        preferenceError = error.message;
      }
      _safeEmit(
        state.copyWith(
          plans: plans,
          preference: preference,
          isLoading: false,
          error: preferenceError,
          selected: state.selected == null
              ? null
              : plans
                    .where((plan) => plan.id == state.selected!.id)
                    .firstOrNull,
          clearSelected:
              state.selected != null &&
              !plans.any((plan) => plan.id == state.selected!.id),
        ),
      );
    } on PlanningFailure catch (error) {
      _safeEmit(state.copyWith(isLoading: false, error: error.message));
    } catch (_) {
      _safeEmit(
        state.copyWith(
          isLoading: false,
          error: 'Não foi possível carregar os planos. Tente novamente.',
        ),
      );
    }
  }

  Future<void> select(String planId) async {
    if (state.isLoading || state.isSaving) return;
    _safeEmit(state.copyWith(isLoading: true));
    try {
      final plan = await _repository.get(planId);
      _safeEmit(
        state.copyWith(selected: plan, plans: _upsert(plan), isLoading: false),
      );
    } on PlanningFailure catch (error) {
      _safeEmit(state.copyWith(isLoading: false, error: error.message));
      if (error.isNotFound && !isClosed) await load();
    } catch (_) {
      _safeEmit(
        state.copyWith(
          isLoading: false,
          error: 'Não foi possível abrir o plano. Tente novamente.',
        ),
      );
    }
  }

  void closeDetail() => _safeEmit(state.copyWith(clearSelected: true));

  Future<void> generate() =>
      _save(() => _repository.generate(), 'Plano semanal gerado.');

  Future<void> confirm() async {
    final plan = state.selected;
    if (plan == null || plan.isConfirmed) return;
    await _save(() => _repository.confirm(plan.id), 'Plano confirmado.');
  }

  Future<void> _save(
    Future<WeeklyPlan> Function() action,
    String notice,
  ) async {
    if (state.isSaving || state.isLoading) return;
    _safeEmit(state.copyWith(isSaving: true));
    try {
      final plan = await action();
      _safeEmit(
        state.copyWith(
          selected: plan,
          plans: _upsert(plan),
          isSaving: false,
          notice: notice,
        ),
      );
    } on PlanningFailure catch (error) {
      _safeEmit(state.copyWith(isSaving: false, error: error.message));
      if (error.isConflict && !isClosed) {
        await load();
        _safeEmit(state.copyWith(error: error.message));
      }
    } catch (_) {
      _safeEmit(
        state.copyWith(
          isSaving: false,
          error: 'Não foi possível salvar o plano. Tente novamente.',
        ),
      );
    }
  }

  Future<void> updatePreference(WeeklyPlanningPreference value) async {
    if (state.isSaving) return;
    _safeEmit(state.copyWith(isSaving: true));
    try {
      final preference = await _repository.updatePreference(value);
      _safeEmit(
        state.copyWith(
          preference: preference,
          isSaving: false,
          notice: 'Preferência salva.',
        ),
      );
    } on PlanningFailure catch (error) {
      _safeEmit(state.copyWith(isSaving: false, error: error.message));
    } catch (_) {
      _safeEmit(
        state.copyWith(
          isSaving: false,
          error: 'Não foi possível salvar a preferência. Tente novamente.',
        ),
      );
    }
  }

  List<WeeklyPlan> _upsert(WeeklyPlan plan) {
    final plans = [...state.plans.where((item) => item.id != plan.id), plan];
    plans.sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return plans;
  }
}
