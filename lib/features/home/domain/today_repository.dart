class TodayMeal {
  const TodayMeal({
    required this.id,
    required this.name,
    required this.mealType,
    required this.date,
    required this.time,
    required this.order,
    required this.itemCount,
  });

  final String id;
  final String name;
  final String mealType;
  final String date;
  final String? time;
  final int order;
  final int itemCount;
}

enum CompletionType { completed, notCompleted, substituted }

class CompletionEvent {
  const CompletionEvent({
    required this.plannedMealId,
    required this.type,
    required this.occurredAt,
    required this.createdAt,
  });

  final String plannedMealId;
  final CompletionType type;
  final DateTime occurredAt;
  final DateTime createdAt;
}

class TodayData {
  const TodayData({required this.meals, required this.latestEvents});

  final List<TodayMeal> meals;
  final Map<String, CompletionEvent> latestEvents;
}

abstract interface class TodayRepository {
  Future<TodayData> load(DateTime date);

  Future<CompletionEvent> record(TodayMeal meal, CompletionType type);
}

class TodayFailure implements Exception {
  const TodayFailure(this.message);

  final String message;
}
