import '../../prescription/domain/current_prescription.dart';
import 'weekly_plan.dart';

/// O que a tela de troca mostra para um item: o original da prescrição e as
/// trocas autorizadas (Q4, Q19). Vem da prescrição atual, pelo
/// `prescribedMealItemId` do item planejado.
class ItemSubstitutions {
  const ItemSubstitutions({
    required this.original,
    required this.options,
    required this.order,
  });

  /// Alimento e porção prescritos.
  final PrescribedFoodRef original;

  /// Voltar ao original (se o item já foi trocado) e as substituições
  /// autorizadas, sem repetir o que o item já usa.
  final List<SubstitutionOption> options;

  /// Ordem do item na prescrição; o servidor exige essa ordem na troca.
  final int order;
}

/// `null` quando não há como trocar: sem prescrição, item sem origem na
/// prescrição atual (por exemplo, plano de uma versão anterior) ou sem
/// substituições autorizadas.
ItemSubstitutions? substitutionsFor(
  CurrentPrescription? prescription,
  PlannedItem item,
) {
  final sourceId = item.prescribedMealItemId;
  if (prescription == null || sourceId == null) return null;
  PrescribedItem? source;
  for (final meal in prescription.meals) {
    for (final candidate in meal.items) {
      if (candidate.id == sourceId) source = candidate;
    }
  }
  if (source == null || source.substitutions.isEmpty) return null;
  bool isCurrent(PrescribedFoodRef ref) =>
      ref.foodId == item.foodId && ref.foodPortionId == item.foodPortionId;
  final options = <SubstitutionOption>[
    if (!isCurrent(source))
      SubstitutionOption(
        foodId: source.foodId,
        foodPortionId: source.foodPortionId,
        quantity: source.quantity,
        unit: source.unit,
      ),
    for (final substitution in source.substitutions)
      if (!isCurrent(substitution))
        SubstitutionOption(
          foodId: substitution.foodId,
          foodPortionId: substitution.foodPortionId,
          quantity: substitution.quantity,
          unit: substitution.unit,
          allowedSubstitutionId: substitution.id,
        ),
  ];
  if (options.isEmpty) return null;
  return ItemSubstitutions(
    original: source,
    options: options,
    order: source.order,
  );
}
