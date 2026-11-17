import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatting/decimal.dart';
import '../../domain/current_prescription.dart';
import '../../domain/current_prescription_repository.dart';
import '../cubit/prescription_cubit.dart';
import '../widgets/no_prescription_empty_state.dart';

const _mealTypeLabels = {
  'BREAKFAST': 'Café da manhã',
  'LUNCH': 'Almoço',
  'SNACK': 'Lanche',
  'DINNER': 'Jantar',
};

/// Prescrição vigente, somente leitura (Q8).
class PrescriptionPage extends StatelessWidget {
  const PrescriptionPage({
    super.key,
    required this.repository,
    this.nutritionistName,
    this.resolveFoodName,
  });

  final CurrentPrescriptionRepository repository;

  /// Nome do nutricionista (o servidor só devolve o id do autor).
  final String? nutritionistName;
  final FoodNameResolver? resolveFoodName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PrescriptionCubit(repository, resolveFoodName: resolveFoodName)
            ..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Minha prescrição')),
        body: BlocBuilder<PrescriptionCubit, PrescriptionState>(
          builder: (context, state) => switch (state.status) {
            PrescriptionStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            PrescriptionStatus.empty => const NoPrescriptionEmptyState(),
            PrescriptionStatus.error => _ErrorView(
              message: state.errorMessage ?? '',
              onRetry: () => context.read<PrescriptionCubit>().load(),
            ),
            PrescriptionStatus.ready => _Content(
              prescription: state.prescription!,
              foodNames: state.foodNames,
              nutritionistName: nutritionistName,
            ),
          },
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

String _date(DateTime value) {
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

class _Content extends StatelessWidget {
  const _Content({
    required this.prescription,
    required this.foodNames,
    this.nutritionistName,
  });

  final CurrentPrescription prescription;
  final Map<String, String> foodNames;
  final String? nutritionistName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = prescription;
    final published = p.publishedAt;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (p.title != null)
          Text(p.title!, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Versão ${p.number}'),
        if (published != null) Text('Publicada em ${_date(published)}'),
        Text(
          nutritionistName == null
              ? 'Publicada pelo seu nutricionista'
              : 'Nutricionista: $nutritionistName',
        ),
        if (p.planningMode != null) Text('Modo: ${p.planningMode!.label}'),
        if (!p.targets.isEmpty) ...[
          const SizedBox(height: 16),
          Text('Metas diárias', style: theme.textTheme.titleMedium),
          if (p.targets.energyKcal != null)
            Text('Energia: ${formatDecimal(p.targets.energyKcal)} kcal'),
          if (p.targets.protein != null)
            Text('Proteínas: ${formatDecimal(p.targets.protein)} g'),
          if (p.targets.carbohydrate != null)
            Text('Carboidratos: ${formatDecimal(p.targets.carbohydrate)} g'),
          if (p.targets.lipids != null)
            Text('Lipídios: ${formatDecimal(p.targets.lipids)} g'),
        ],
        const SizedBox(height: 16),
        Text('Refeições', style: theme.textTheme.titleMedium),
        for (final meal in p.meals) _MealCard(meal: meal, foodNames: foodNames),
        if (p.notes != null) ...[
          const SizedBox(height: 16),
          Text('Observações', style: theme.textTheme.titleMedium),
          Text(p.notes!),
        ],
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, required this.foodNames});

  final PrescribedMeal meal;
  final Map<String, String> foodNames;

  String _food(PrescribedFoodRef ref) {
    final name = foodNames[ref.foodId] ?? 'Alimento';
    return '$name — ${formatDecimal(ref.quantity)} ${ref.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _mealTypeLabels[meal.mealType] ?? meal.mealType;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meal.name, style: theme.textTheme.titleSmall),
            Text(
              meal.suggestedTime == null
                  ? category
                  : '$category · ${meal.suggestedTime}',
            ),
            if (meal.notes != null) Text(meal.notes!),
            for (final item in meal.items) ...[
              const SizedBox(height: 8),
              Text(_food(item)),
              if (item.notes != null) Text(item.notes!),
              if (item.substitutions.isNotEmpty) ...[
                Text(
                  'Substituições autorizadas',
                  style: theme.textTheme.labelMedium,
                ),
                for (final s in item.substitutions) Text('• ${_food(s)}'),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
