/// Estado da categoria do dia, sempre vindo do servidor (M-03): o app não o
/// calcula. Nomes na tela: Registrada, Parcial e Sem registro (A-05).
enum CategoryState {
  notLogged('NOT_LOGGED'),
  partial('PARTIAL'),
  logged('LOGGED');

  const CategoryState(this.code);

  final String code;

  static CategoryState? fromCode(Object? code) {
    for (final state in values) {
      if (state.code == code) return state;
    }
    return null;
  }
}

/// Execução ativa de uma categoria no dia (`meal-executions?date=`).
class DayExecution {
  const DayExecution({
    required this.id,
    required this.version,
    required this.mealType,
    required this.time,
    required this.itemCount,
    required this.withSubstitution,
  });

  final String id;
  final int version;
  final String mealType;

  /// `HH:mm`, ou nulo se o servidor não devolveu horário.
  final String? time;
  final int itemCount;

  /// Algum item usou uma substituição autorizada (`allowedSubstitutionId`).
  final bool withSubstitution;
}

/// Uma das quatro categorias do dia (`daily-meal-categories`).
class DayCategory {
  const DayCategory({
    required this.mealType,
    required this.state,
    required this.canRegister,
    this.blockedReason,
    this.plannedMealId,
    this.coveredItemCount = 0,
    this.uncoveredItemCount = 0,
    this.uncoveredPlannedItemIds = const [],
    this.executions = const [],
    this.suggestedTime,
  });

  final String mealType;
  final CategoryState state;
  final bool canRegister;
  final String? blockedReason;

  /// Nulo em `FREE` sem refeição planejada: o registro é livre.
  final String? plannedMealId;
  final int coveredItemCount;
  final int uncoveredItemCount;
  final List<String> uncoveredPlannedItemIds;
  final List<DayExecution> executions;

  /// `suggestedTime` (`HH:mm`) da prescrição para a categoria (Q17).
  final String? suggestedTime;

  /// Marca "Com substituição" (A-05).
  bool get withSubstitution => executions.any((e) => e.withSubstitution);

  bool get hasPlannedItems => coveredItemCount + uncoveredItemCount > 0;
}

/// Intervalo de datas civis; [end] nulo é um período em aberto.
class DatePeriod {
  const DatePeriod({required this.start, this.end});

  final DateTime start;
  final DateTime? end;

  bool includes(DateTime date) {
    final day = civilDay(date);
    return !day.isBefore(start) && (end == null || !day.isAfter(end!));
  }
}

/// `calendar-periods` (Q7, Q20): só estes dias são selecionáveis.
class CalendarPeriods {
  const CalendarPeriods({
    this.plans = const [],
    this.prescriptions = const [],
    this.freeExecutionDates = const [],
  });

  final List<DatePeriod> plans;
  final List<DatePeriod> prescriptions;
  final List<DateTime> freeExecutionDates;

  bool get isEmpty =>
      plans.isEmpty && prescriptions.isEmpty && freeExecutionDates.isEmpty;

  bool isSelectable(DateTime date) {
    final day = civilDay(date);
    return plans.any((p) => p.includes(day)) ||
        prescriptions.any((p) => p.includes(day)) ||
        freeExecutionDates.any((d) => d == day);
  }

  /// Primeiro dia selecionável.
  DateTime? get first {
    final days = [
      for (final p in [...plans, ...prescriptions]) p.start,
      ...freeExecutionDates,
    ];
    if (days.isEmpty) return null;
    return days.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Último dia selecionável; períodos em aberto vão até um ano após [today].
  DateTime? last(DateTime today) {
    final days = <DateTime>[
      for (final p in [...plans, ...prescriptions])
        p.end ?? civilDay(today).add(const Duration(days: 365)),
      ...freeExecutionDates,
    ];
    if (days.isEmpty) return null;
    return days.reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

/// Data civil sem hora, no fuso local.
DateTime civilDay(DateTime date) => DateTime(date.year, date.month, date.day);

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
    required this.date,
    required this.categories,
    this.calendar,
    this.summary,
    this.hasPrescription = true,
  });

  final DateTime date;

  /// As quatro categorias, na ordem do servidor.
  final List<DayCategory> categories;

  /// Nulo quando `calendar-periods` não pôde ser lido.
  final CalendarPeriods? calendar;

  /// Nulo quando o resumo não pôde ser lido.
  final DailySummary? summary;

  /// Falso só quando o servidor respondeu `404 PRESCRIPTION_NOT_FOUND`.
  final bool hasPrescription;

  /// Q24/A-01: sem prescrição e sem plano nem registro no dia, o Início mostra
  /// o estado vazio no lugar das quatro categorias. Dia coberto por plano em
  /// curso (alguma categoria com refeição planejada) segue normal.
  bool get noPrescription =>
      !hasPrescription &&
      categories.every((c) => c.plannedMealId == null && c.executions.isEmpty);
}

/// Resultado de remover uma execução: o token vale até [restoreExpiresAt].
class RemovedExecution {
  const RemovedExecution({
    required this.id,
    required this.restoreToken,
    required this.restoreExpiresAt,
  });

  final String id;
  final String restoreToken;
  final DateTime restoreExpiresAt;
}

abstract interface class TodayRepository {
  Future<TodayData> load(DateTime date);

  /// `DELETE meal-executions/{id}` (Q6).
  Future<RemovedExecution> remove(DayExecution execution);

  /// `POST meal-executions/{id}/restore`, dentro da janela do token.
  Future<void> restore(RemovedExecution removed);
}

class TodayFailure implements Exception {
  const TodayFailure(this.message);

  final String message;
}
