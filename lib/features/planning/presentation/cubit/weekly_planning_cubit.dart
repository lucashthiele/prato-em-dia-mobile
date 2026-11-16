import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../prescription/domain/current_prescription.dart';
import '../../../prescription/domain/current_prescription_repository.dart';
import '../../domain/weekly_plan.dart';
import '../../domain/weekly_planning_repository.dart';

/// Nome do alimento por id (catálogo); `null` se não achar.
typedef FoodNameResolver = Future<String?> Function(String foodId);

class WeeklyPlanningState {
  const WeeklyPlanningState({
    this.plans = const [],
    this.selected,
    this.preference,
    this.prescription,
    this.noPrescription = false,
    this.foodNames = const {},
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.notice,
  });

  final List<WeeklyPlan> plans;
  final WeeklyPlan? selected;
  final WeeklyPlanningPreference? preference;

  /// Prescrição atual; autoriza as substituições (Q19).
  final CurrentPrescription? prescription;

  /// Verdadeiro quando o paciente não tem prescrição (Q24, A-01): some a ação
  /// de gerar e o estado vazio aparece quando não há plano.
  final bool noPrescription;
  final Map<String, String> foodNames;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? notice;

  WeeklyPlanningState copyWith({
    List<WeeklyPlan>? plans,
    WeeklyPlan? selected,
    bool clearSelected = false,
    WeeklyPlanningPreference? preference,
    CurrentPrescription? prescription,
    bool? noPrescription,
    Map<String, String>? foodNames,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? notice,
  }) => WeeklyPlanningState(
    plans: plans ?? this.plans,
    selected: clearSelected ? null : selected ?? this.selected,
    preference: preference ?? this.preference,
    prescription: noPrescription == true
        ? null
        : prescription ?? this.prescription,
    noPrescription: noPrescription ?? this.noPrescription,
    foodNames: foodNames ?? this.foodNames,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    error: error,
    notice: notice,
  );
}

class WeeklyPlanningCubit extends Cubit<WeeklyPlanningState> {
  WeeklyPlanningCubit(
    this._repository, {
    CurrentPrescriptionRepository? prescriptionRepository,
    this._foodNames,
  }) : _prescriptions = prescriptionRepository,
       super(const WeeklyPlanningState());

  final WeeklyPlanningRepository _repository;
  final CurrentPrescriptionRepository? _prescriptions;
  final FoodNameResolver? _foodNames;

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
      CurrentPrescription? prescription;
      var noPrescription = false;
      if (_prescriptions != null) {
        try {
          prescription = await _prescriptions.fetchCurrent();
          noPrescription = prescription == null;
        } catch (_) {
          // Sem saber, não esconde a ação: o servidor recusa se for o caso.
          prescription = state.prescription;
          noPrescription = false;
        }
      }
      _safeEmit(
        state.copyWith(
          plans: plans,
          preference: preference,
          prescription: prescription,
          noPrescription: noPrescription,
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
      await _resolveNames();
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
      await _resolveNames();
    } on PlanningFailure catch (error) {
      _safeEmit(state.copyWith(isLoading: false, error: error.message));
      if (error.isNotFound && !isClosed) await _reloadKeepingMessage();
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

  /// Gera ou regenera (Q24: um `404` aqui significa sem prescrição; M-05: um
  /// `409` de geração concorrente recarrega o plano com a mensagem).
  Future<void> generate() async {
    if (state.isSaving || state.isLoading) return;
    _safeEmit(state.copyWith(isSaving: true));
    try {
      final plan = await _repository.generate();
      _safeEmit(
        state.copyWith(selected: plan, plans: _upsert(plan), isSaving: false),
      );
      // Regenerar substitui só os dias sobrepostos: relê todos os planos.
      await _reloadKeepingMessage(notice: 'Plano semanal gerado.');
    } on PlanningFailure catch (error) {
      if (error.isNotFound) {
        _safeEmit(state.copyWith(isSaving: false, noPrescription: true));
        return;
      }
      _safeEmit(state.copyWith(isSaving: false, error: error.message));
      if (error.isConflict) await _reloadKeepingMessage(error: error.message);
    } catch (_) {
      _safeEmit(
        state.copyWith(
          isSaving: false,
          error: 'Não foi possível gerar o plano. Tente novamente.',
        ),
      );
    }
  }

  Future<void> confirm() async {
    final plan = state.selected;
    if (plan == null || plan.isConfirmed) return;
    await _save(() => _repository.confirm(plan.id), 'Plano confirmado.');
  }

  /// Troca o alimento/porção do item (Q19): grava na hora pelo `PATCH`. Se o
  /// servidor recusar, mostra a mensagem e recarrega o plano.
  Future<void> substituteItem({
    required String mealId,
    required int itemIndex,
    required SubstitutionOption option,
    required int itemOrder,
  }) async {
    final plan = state.selected;
    if (plan == null || state.isSaving || state.isLoading) return;
    _safeEmit(state.copyWith(isSaving: true));
    try {
      final updated = await _repository.update(
        plan.id,
        buildSubstitutionPatchBody(
          plan,
          mealId: mealId,
          itemIndex: itemIndex,
          option: option,
          itemOrder: itemOrder,
        ),
      );
      _safeEmit(
        state.copyWith(
          selected: updated,
          plans: _upsert(updated),
          isSaving: false,
          notice: 'Troca confirmada.',
        ),
      );
      await _resolveNames();
    } on PlanningFailure catch (error) {
      _safeEmit(state.copyWith(isSaving: false, error: error.message));
      await _reloadKeepingMessage(error: error.message);
    } catch (_) {
      _safeEmit(
        state.copyWith(
          isSaving: false,
          error: 'Não foi possível confirmar a troca. Tente novamente.',
        ),
      );
    }
  }

  /// Exclui o plano (Q5) e recarrega.
  Future<void> deletePlan(String planId) async {
    if (state.isSaving || state.isLoading) return;
    _safeEmit(state.copyWith(isSaving: true));
    try {
      await _repository.delete(planId);
      _safeEmit(state.copyWith(isSaving: false, clearSelected: true));
      await _reloadKeepingMessage(notice: 'Plano excluído.');
    } on PlanningFailure catch (error) {
      _safeEmit(state.copyWith(isSaving: false, error: error.message));
      if (error.isNotFound) {
        _safeEmit(state.copyWith(clearSelected: true));
        await _reloadKeepingMessage(error: error.message);
      }
    } catch (_) {
      _safeEmit(
        state.copyWith(
          isSaving: false,
          error: 'Não foi possível excluir o plano. Tente novamente.',
        ),
      );
    }
  }

  Future<void> _reloadKeepingMessage({String? error, String? notice}) async {
    if (isClosed) return;
    await load();
    if (error != null || notice != null) {
      _safeEmit(state.copyWith(error: error, notice: notice));
    }
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
      if (error.isConflict) await _reloadKeepingMessage(error: error.message);
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

  /// Busca no catálogo os nomes dos alimentos que a tela ainda não conhece:
  /// itens dos planos e opções de troca. Falhas deixam o rótulo genérico.
  Future<void> _resolveNames() async {
    final resolver = _foodNames;
    if (resolver == null || isClosed) return;
    final ids = <String>{
      for (final plan in state.plans)
        for (final meal in plan.meals)
          for (final item in meal.items) item.foodId,
      for (final meal in state.prescription?.meals ?? const <PrescribedMeal>[])
        for (final item in meal.items) ...[
          item.foodId,
          for (final substitution in item.substitutions) substitution.foodId,
        ],
    }..removeAll(state.foodNames.keys);
    if (ids.isEmpty) return;
    final names = {...state.foodNames};
    await Future.wait([
      for (final id in ids)
        () async {
          try {
            final name = await resolver(id);
            if (name != null) names[id] = name;
          } catch (_) {}
        }(),
    ]);
    _safeEmit(
      state.copyWith(
        foodNames: names,
        error: state.error,
        notice: state.notice,
      ),
    );
  }

  List<WeeklyPlan> _upsert(WeeklyPlan plan) {
    final plans = [...state.plans.where((item) => item.id != plan.id), plan];
    plans.sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return plans;
  }
}
