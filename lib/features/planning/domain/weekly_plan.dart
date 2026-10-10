class WeeklyPlan {
  const WeeklyPlan({
    required this.id,
    required this.prescriptionVersionId,
    required this.planningMode,
    required this.periodStart,
    required this.periodEnd,
    required this.confirmationDeadline,
    required this.status,
    required this.version,
    required this.meals,
  });

  final String id;
  final String prescriptionVersionId;
  final String planningMode;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime confirmationDeadline;
  final String status;
  final int version;
  final List<PlannedMeal> meals;

  bool get isConfirmed => status == 'CONFIRMED';
}

class PlannedMeal {
  const PlannedMeal({
    required this.id,
    required this.date,
    required this.time,
    required this.mealType,
    required this.name,
    required this.order,
    required this.items,
  });

  final String id;
  final DateTime date;
  final String? time;
  final String mealType;
  final String name;
  final int order;
  final List<PlannedItem> items;
}

class PlannedItem {
  const PlannedItem({
    required this.foodId,
    required this.quantity,
    required this.unit,
  });

  final String foodId;
  final String quantity;
  final String unit;
}

class WeeklyPlanningPreference {
  const WeeklyPlanningPreference({
    required this.dayOfWeek,
    required this.enabled,
  });

  final String dayOfWeek;
  final bool enabled;
}
