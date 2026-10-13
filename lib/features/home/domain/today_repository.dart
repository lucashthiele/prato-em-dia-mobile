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

class NutrientAmount {
  const NutrientAmount(this.amount, this.unit);

  final num amount;
  final String unit;
}

/// Daily nutrition totals by nutrient code. `prescribed` is empty when the
/// day has no plan or the prescription defines no targets.
class DailySummary {
  const DailySummary({
    this.prescribed = const {},
    this.planned = const {},
    this.realized = const {},
  });

  final Map<String, NutrientAmount> prescribed;
  final Map<String, NutrientAmount> planned;
  final Map<String, NutrientAmount> realized;
}

class TodayData {
  const TodayData({
    required this.meals,
    required this.latestEvents,
    this.availablePeriods = const [],
    this.summary,
  });

  /// Null when the summary could not be loaded.
  final DailySummary? summary;

  final List<TodayMeal> meals;
  final Map<String, CompletionEvent> latestEvents;
  final List<TodayPeriod> availablePeriods;
}

class TodayPeriod {
  const TodayPeriod({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool includes(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

abstract interface class TodayRepository {
  Future<TodayData> load(DateTime date);

  Future<CompletionEvent> record(TodayMeal meal, CompletionType type);
}

class TodayFailure implements Exception {
  const TodayFailure(this.message);

  final String message;
}
