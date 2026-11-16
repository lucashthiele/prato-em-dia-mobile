/// Modo de planejamento da prescrição (`PlanningMode` no servidor).
enum PlanningMode {
  free('FREE', 'Livre'),
  restricted('RESTRICTED', 'Restrito'),
  substitutionsOnly('SUBSTITUTIONS_ONLY', 'Somente substituições');

  const PlanningMode(this.code, this.label);

  final String code;

  /// Nome em pt-BR para exibição.
  final String label;

  static PlanningMode? fromCode(Object? code) {
    for (final mode in values) {
      if (mode.code == code) return mode;
    }
    return null;
  }
}

/// Alimento/porção/quantidade/unidade de um item ou de uma substituição.
class PrescribedFoodRef {
  const PrescribedFoodRef({
    required this.foodId,
    required this.quantity,
    required this.unit,
    this.foodPortionId,
    this.notes,
  });

  final String foodId;
  final String? foodPortionId;

  /// Decimal vindo do servidor como número ou string, mantido como texto.
  final String quantity;
  final String unit;
  final String? notes;
}

class AllowedSubstitution extends PrescribedFoodRef {
  const AllowedSubstitution({
    required this.id,
    required super.foodId,
    required super.quantity,
    required super.unit,
    super.foodPortionId,
    super.notes,
  });

  final String id;
}

class PrescribedItem extends PrescribedFoodRef {
  const PrescribedItem({
    required this.id,
    required super.foodId,
    required super.quantity,
    required super.unit,
    required this.order,
    this.substitutions = const [],
    super.foodPortionId,
    super.notes,
  });

  final String id;
  final int order;
  final List<AllowedSubstitution> substitutions;
}

class PrescribedMeal {
  const PrescribedMeal({
    required this.id,
    required this.name,
    required this.mealType,
    required this.order,
    this.suggestedTime,
    this.notes,
    this.items = const [],
  });

  final String id;
  final String name;

  /// `BREAKFAST`, `LUNCH`, `SNACK` ou `DINNER`.
  final String mealType;
  final int order;

  /// Horário sugerido no formato `HH:mm`, quando houver.
  final String? suggestedTime;
  final String? notes;
  final List<PrescribedItem> items;
}

/// Metas diárias (todas opcionais): kcal e gramas.
class NutritionTargets {
  const NutritionTargets({
    this.energyKcal,
    this.protein,
    this.carbohydrate,
    this.lipids,
  });

  final String? energyKcal;
  final String? protein;
  final String? carbohydrate;
  final String? lipids;

  bool get isEmpty =>
      energyKcal == null &&
      protein == null &&
      carbohydrate == null &&
      lipids == null;
}

/// Versão vigente (publicada) da prescrição do paciente.
class CurrentPrescription {
  const CurrentPrescription({
    required this.id,
    required this.number,
    required this.createdByUserId,
    this.title,
    this.notes,
    this.publishedAt,
    this.planningMode,
    this.meals = const [],
    this.targets = const NutritionTargets(),
  });

  final String id;
  final int number;
  final String? title;
  final String? notes;

  /// O servidor só devolve o id da conta autora, não o nome (ver HANDOFF).
  final String? createdByUserId;
  final DateTime? publishedAt;

  /// O `VersionOutput` atual não traz o modo; fica nulo até o servidor expor.
  final PlanningMode? planningMode;
  final List<PrescribedMeal> meals;
  final NutritionTargets targets;

  /// `suggestedTime` (`HH:mm`) da primeira refeição da categoria [mealType].
  String? suggestedTimeFor(String mealType) {
    for (final meal in meals) {
      if (meal.mealType == mealType && meal.suggestedTime != null) {
        return meal.suggestedTime;
      }
    }
    return null;
  }
}
