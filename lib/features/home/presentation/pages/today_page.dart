import 'package:flutter/material.dart';

/// The first authenticated experience.
///
/// Tracking endpoints are not available yet, so this page intentionally keeps
/// the sample plan in memory. Its interaction and visual states mirror the
/// future tracking flow without persisting a completion event locally.
class TodayPage extends StatefulWidget {
  const TodayPage({required this.onLogout, super.key});

  final Future<void> Function() onLogout;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final Set<String> _completedMealIds = {'cafe'};
  bool _isLoggingOut = false;

  static const _meals = [
    _PlannedMeal(
      id: 'cafe',
      period: 'Café da manhã',
      time: '07:30',
      title: 'Omelete com tapioca',
      details: '2 ovos, tapioca e mamão',
      calories: 385,
      protein: 28,
      carbohydrates: 41,
      fat: 18,
      icon: Icons.wb_sunny_outlined,
    ),
    _PlannedMeal(
      id: 'almoco',
      period: 'Almoço',
      time: '12:30',
      title: 'Frango grelhado com arroz',
      details: 'Frango, arroz integral e salada',
      calories: 620,
      protein: 48,
      carbohydrates: 70,
      fat: 20,
      icon: Icons.restaurant_outlined,
    ),
    _PlannedMeal(
      id: 'lanche',
      period: 'Lanche da tarde',
      time: '16:00',
      title: 'Iogurte com frutas',
      details: 'Iogurte natural, banana e aveia',
      calories: 275,
      protein: 14,
      carbohydrates: 38,
      fat: 7,
      icon: Icons.local_cafe_outlined,
    ),
    _PlannedMeal(
      id: 'jantar',
      period: 'Jantar',
      time: '20:00',
      title: 'Sopa de legumes com carne',
      details: 'Legumes, carne magra e torradas',
      calories: 465,
      protein: 36,
      carbohydrates: 42,
      fat: 16,
      icon: Icons.dinner_dining_outlined,
    ),
  ];

  int get _consumedCalories => _meals
      .where((meal) => _completedMealIds.contains(meal.id))
      .fold(0, (sum, meal) => sum + meal.calories);

  int get _consumedProtein => _sumMacro((meal) => meal.protein);

  int get _consumedCarbohydrates => _sumMacro((meal) => meal.carbohydrates);

  int get _consumedFat => _sumMacro((meal) => meal.fat);

  int _sumMacro(int Function(_PlannedMeal meal) macro) => _meals
      .where((meal) => _completedMealIds.contains(meal.id))
      .fold(0, (sum, meal) => sum + macro(meal));

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _confirmMeal(_PlannedMeal meal) async {
    if (_completedMealIds.contains(meal.id)) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirmar refeição',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Você realizou “${meal.title}” como foi planejado?'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Confirmar como planejada'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: const Text('Agora não'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _completedMealIds.add(meal.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${meal.period} confirmada para hoje.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = _consumedCalories / 1745;
    final date = _todayLabel(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Olá, Marina',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(date, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sair da conta',
                        onPressed: _isLoggingOut ? null : _logout,
                        icon: _isLoggingOut
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    label:
                        'Consumo de hoje: $_consumedCalories de 1745 quilocalorias',
                    child: _DailySummaryCard(
                      calories: _consumedCalories,
                      progress: progress.clamp(0, 1),
                      protein: _consumedProtein,
                      carbohydrates: _consumedCarbohydrates,
                      fat: _consumedFat,
                      scheme: scheme,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Sua programação', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Toque em uma refeição para registrar como foi seu dia.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  ..._meals.map(
                    (meal) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MealCard(
                        meal: meal,
                        isCompleted: _completedMealIds.contains(meal.id),
                        onConfirm: () => _confirmMeal(meal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Plano demonstrativo · integração de tracking em breve',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({
    required this.calories,
    required this.progress,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.scheme,
  });

  final int calories;
  final double progress;
  final int protein;
  final int carbohydrates;
  final int fat;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consumo de hoje',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          RichText(
            key: const Key('daily-calories'),
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(text: '$calories '),
                TextSpan(
                  text: '/ 1.745 kcal',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _Macro(
                  label: 'Proteínas',
                  value: '$protein g',
                  target: 'de 115 g',
                ),
              ),
              Expanded(
                child: _Macro(
                  label: 'Carboidratos',
                  value: '$carbohydrates g',
                  target: 'de 190 g',
                ),
              ),
              Expanded(
                child: _Macro(
                  label: 'Gorduras',
                  value: '$fat g',
                  target: 'de 58 g',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({
    required this.label,
    required this.value,
    required this.target,
  });

  final String label;
  final String value;
  final String target;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      Text(target, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.isCompleted,
    required this.onConfirm,
  });

  final _PlannedMeal meal;
  final bool isCompleted;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: !isCompleted,
      label: isCompleted
          ? '${meal.period}, realizada: ${meal.title}'
          : '${meal.period}, ${meal.title}, ${meal.calories} quilocalorias',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isCompleted ? null : onConfirm,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : meal.icon,
                    color: isCompleted
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${meal.period} · ${meal.time}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meal.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meal.details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isCompleted)
                  Text(
                    'Realizada',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.primary),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannedMeal {
  const _PlannedMeal({
    required this.id,
    required this.period,
    required this.time,
    required this.title,
    required this.details,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.icon,
  });

  final String id;
  final String period;
  final String time;
  final String title;
  final String details;
  final int calories;
  final int protein;
  final int carbohydrates;
  final int fat;
  final IconData icon;
}

String _todayLabel(DateTime date) {
  const weekdays = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}';
}
