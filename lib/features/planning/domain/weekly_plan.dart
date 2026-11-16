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
    required this.mealType,
    required this.name,
    required this.order,
    required this.items,
    this.prescribedMealId,
  });

  final String id;
  final String? prescribedMealId;
  final DateTime date;
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
    this.id,
    this.prescribedMealItemId,
    this.allowedSubstitutionId,
    this.foodPortionId,
    this.order = 0,
  });

  final String? id;

  /// Item da prescrição de origem; é por ele que se acham as substituições
  /// autorizadas na prescrição atual.
  final String? prescribedMealItemId;

  /// Preenchido quando o item já é uma substituição autorizada.
  final String? allowedSubstitutionId;
  final String foodId;
  final String? foodPortionId;
  final String quantity;
  final String unit;
  final int order;

  bool get isSubstituted => allowedSubstitutionId != null;
}

class WeeklyPlanningPreference {
  const WeeklyPlanningPreference({
    required this.dayOfWeek,
    required this.enabled,
  });

  final String dayOfWeek;
  final bool enabled;
}

/// Uma troca possível para um item: alimento/porção/quantidade de destino.
class SubstitutionOption {
  const SubstitutionOption({
    required this.foodId,
    required this.quantity,
    required this.unit,
    this.foodPortionId,
    this.allowedSubstitutionId,
  });

  final String foodId;
  final String? foodPortionId;
  final String quantity;
  final String unit;

  /// Nulo quando a opção é voltar ao item prescrito original.
  final String? allowedSubstitutionId;
}

/// Refeições vistas pelo paciente: no máximo uma por dia e categoria (M-05).
/// O servidor já deixa o substituído fora das leituras; aqui só se protege a
/// tela caso duplicatas cheguem, mantendo a última da lista.
List<PlannedMeal> activeMeals(WeeklyPlan plan) {
  final byKey = <String, PlannedMeal>{};
  for (final meal in plan.meals) {
    byKey['${_dayKey(meal.date)}|${meal.mealType}'] = meal;
  }
  return byKey.values.toList()..sort((a, b) {
    final date = a.date.compareTo(b.date);
    return date != 0 ? date : a.order.compareTo(b.order);
  });
}

String dayKey(DateTime date) => _dayKey(date);

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Corpo do `PATCH /api/v1/weekly-plans/{planId}` que troca só o alimento e a
/// porção do item [itemIndex] da refeição [mealId]. Leva a `version` e a lista
/// inteira de refeições (data, categoria, nome, ordem e itens) sem mover nada.
/// Quantidade, unidade e ordem do item vêm da opção e de [itemOrder], porque o
/// servidor exige que sejam os da substituição autorizada.
Map<String, dynamic> buildSubstitutionPatchBody(
  WeeklyPlan plan, {
  required String mealId,
  required int itemIndex,
  required SubstitutionOption option,
  required int itemOrder,
}) => {
  'version': plan.version,
  'meals': [
    for (final meal in plan.meals)
      {
        'id': meal.id,
        'date': _dayKey(meal.date),
        'mealType': meal.mealType,
        'name': meal.name,
        'order': meal.order,
        'items': [
          for (final (index, item) in meal.items.indexed)
            if (meal.id == mealId && index == itemIndex)
              {
                'id': item.id,
                'foodId': option.foodId,
                'foodPortionId': option.foodPortionId,
                'quantity': _number(option.quantity),
                'unit': option.unit,
                'order': itemOrder,
              }
            else
              {
                'id': item.id,
                'foodId': item.foodId,
                'foodPortionId': item.foodPortionId,
                'quantity': _number(item.quantity),
                'unit': item.unit,
                'order': item.order,
              },
        ],
      },
  ],
};

Object _number(String value) => num.tryParse(value) ?? value;
