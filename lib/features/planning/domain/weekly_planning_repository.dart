import 'weekly_plan.dart';

abstract interface class WeeklyPlanningRepository {
  Future<List<WeeklyPlan>> list();
  Future<WeeklyPlan> get(String planId);
  Future<WeeklyPlan> generate();
  Future<WeeklyPlan> confirm(String planId);
  Future<WeeklyPlanningPreference> getPreference();
  Future<WeeklyPlanningPreference> updatePreference(
    WeeklyPlanningPreference value,
  );
}

class PlanningFailure implements Exception {
  const PlanningFailure(
    this.message, {
    this.isConflict = false,
    this.isNotFound = false,
  });

  final String message;
  final bool isConflict;
  final bool isNotFound;
}
