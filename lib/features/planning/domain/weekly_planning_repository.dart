import 'weekly_plan.dart';

abstract interface class WeeklyPlanningRepository {
  Future<List<WeeklyPlan>> list();
  Future<WeeklyPlan> get(String planId);
  Future<WeeklyPlan> generate();
  Future<WeeklyPlan> confirm(String planId);

  /// `PATCH` do plano com [body] já montado (`buildSubstitutionPatchBody`).
  Future<WeeklyPlan> update(String planId, Map<String, dynamic> body);
  Future<void> delete(String planId);
  Future<WeeklyPlanningPreference> getPreference();
  Future<WeeklyPlanningPreference> updatePreference(
    WeeklyPlanningPreference value,
  );
}

class PlanningFailure implements Exception {
  const PlanningFailure(this.message, {this.status, this.code});

  final String message;
  final int? status;

  /// Código do catálogo de erros do servidor, quando houve resposta.
  final String? code;

  /// Qualquer `409`: o plano mudou ou há geração em andamento.
  bool get isConflict => status == 409;

  /// `409 WEEKLY_PLAN_GENERATION_CONFLICT` (M-05).
  bool get isGenerationConflict => code == 'WEEKLY_PLAN_GENERATION_CONFLICT';

  /// `404 WEEKLY_PLAN_NOT_FOUND`: plano inexistente ou, na geração, sem
  /// prescrição vigente (A-01).
  bool get isNotFound => code == 'WEEKLY_PLAN_NOT_FOUND';

  /// Recusa da alteração: `400 INVALID_PLANNING`.
  bool get isRejected => code == 'INVALID_PLANNING';
}
