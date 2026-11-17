import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/widgets/app_error_banner.dart';
import '../../../prescription/domain/current_prescription.dart';
import '../../../prescription/domain/current_prescription_repository.dart';
import '../../../prescription/presentation/widgets/no_prescription_empty_state.dart';
import '../../domain/substitution_options.dart';
import '../../domain/weekly_plan.dart';
import '../../domain/weekly_planning_repository.dart';
import '../cubit/weekly_planning_cubit.dart';

/// A self-contained patient planning page. The host provides an authenticated repository.
class WeeklyPlanningPage extends StatelessWidget {
  const WeeklyPlanningPage({
    required this.repository,
    this.prescriptionRepository,
    this.foodNames,
    this.onOpenMeal,
    super.key,
  });

  final WeeklyPlanningRepository repository;

  /// Prescrição atual: autoriza as trocas e decide o estado sem prescrição.
  final CurrentPrescriptionRepository? prescriptionRepository;
  final FoodNameResolver? foodNames;
  final Future<void> Function(PlannedMeal meal)? onOpenMeal;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => WeeklyPlanningCubit(
      repository,
      prescriptionRepository: prescriptionRepository,
      foodNames: foodNames,
    )..load(),
    child: _PlanningView(onOpenMeal: onOpenMeal),
  );
}

class _PlanningView extends StatelessWidget {
  const _PlanningView({this.onOpenMeal});

  final Future<void> Function(PlannedMeal meal)? onOpenMeal;

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<WeeklyPlanningCubit, WeeklyPlanningState>(
    listenWhen: (previous, current) =>
        current.notice != null && previous.notice != current.notice,
    listener: (context, state) =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.notice!))),
    builder: (context, state) {
      final cubit = context.read<WeeklyPlanningCubit>();
      return Scaffold(
        appBar: AppBar(
          title: Text(
            state.selected == null ? 'Minha semana' : 'Plano semanal',
          ),
          leading: state.selected == null
              ? null
              : IconButton(
                  tooltip: 'Voltar aos planos',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: cubit.closeDetail,
                ),
          actions: [
            IconButton(
              tooltip: 'Atualizar planos',
              onPressed: state.isLoading || state.isSaving ? null : cubit.load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  28,
                  20,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  if (state.isLoading) const LinearProgressIndicator(),
                  if (state.error != null) ...[
                    _ErrorPanel(message: state.error!, onRetry: cubit.load),
                    const SizedBox(height: 16),
                  ],
                  if (state.selected == null) ...[
                    Text(
                      'Sua rotina alimentar',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (!state.noPrescription) ...[
                      Text(
                        'Veja seus planos ou gere uma nova semana a partir da prescrição publicada.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: state.isLoading || state.isSaving
                            ? null
                            : cubit.generate,
                        icon: state.isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(
                          state.plans.isEmpty
                              ? 'Gerar plano semanal'
                              : 'Regenerar plano',
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (!state.isLoading &&
                        state.plans.isEmpty &&
                        state.noPrescription)
                      const NoPrescriptionEmptyState()
                    else ...[
                      Text(
                        'PLANO ATIVO',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (!state.isLoading && state.plans.isEmpty)
                        const _EmptyCard(
                          message: 'Você ainda não tem um plano semanal. Gere um plano para começar.',
                        ),
                      for (final (index, plan) in _orderedPlans(
                        state.plans,
                      ).indexed) ...[
                        if (index == 1) ...[
                          const SizedBox(height: 12),
                          Text(
                            'HISTÓRICO',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _PlanTile(
                          plan: plan,
                          enabled: !state.isLoading && !state.isSaving,
                          onTap: () => cubit.select(plan.id),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (!state.noPrescription) ...[
                      const SizedBox(height: 20),
                      _PreferenceCard(
                        preference: state.preference,
                        isSaving: state.isSaving,
                        onSave: cubit.updatePreference,
                      ),
                    ],
                  ] else ...[
                    if (state.prescriptionUnavailable) ...[
                      const AppErrorBanner(
                        message:
                            'Não foi possível carregar as substituições '
                            'da sua prescrição. Atualize para tentar de novo.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    _PlanDetail(
                      plan: state.selected!,
                      isSaving: state.isSaving,
                      prescription: state.prescription,
                      foodNames: state.foodNames,
                      onConfirm: cubit.confirm,
                      onDelete: () => cubit.deletePlan(state.selected!.id),
                      onSubstitute: cubit.substituteItem,
                      onOpenMeal: onOpenMeal,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PlanDetail extends StatefulWidget {
  const _PlanDetail({
    required this.plan,
    required this.isSaving,
    required this.prescription,
    required this.foodNames,
    required this.onConfirm,
    required this.onDelete,
    required this.onSubstitute,
    this.onOpenMeal,
  });

  final WeeklyPlan plan;
  final bool isSaving;
  final CurrentPrescription? prescription;
  final Map<String, String> foodNames;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;
  final Future<void> Function({
    required String mealId,
    required int itemIndex,
    required SubstitutionOption option,
    required int itemOrder,
  })
  onSubstitute;
  final Future<void> Function(PlannedMeal meal)? onOpenMeal;

  @override
  State<_PlanDetail> createState() => _PlanDetailState();
}

class _PlanDetailState extends State<_PlanDetail> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.plan.periodStart.year,
      widget.plan.periodStart.month,
      widget.plan.periodStart.day,
    );
  }

  @override
  void didUpdateWidget(covariant _PlanDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.id != widget.plan.id) {
      _selectedDate = DateTime(
        widget.plan.periodStart.year,
        widget.plan.periodStart.month,
        widget.plan.periodStart.day,
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir plano?'),
        content: const Text(
          'O plano deixa de aparecer e o período fica livre para um novo plano. Seus registros de refeições são mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete();
  }

  Future<void> _openSubstitution(
    PlannedMeal meal,
    int index,
    PlannedItem item,
    ItemSubstitutions substitutions,
  ) async {
    final option = await showModalBottomSheet<SubstitutionOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SubstitutionSheet(
        itemName: _foodLabel(widget.foodNames, item.foodId),
        original: substitutions.original,
        options: substitutions.options,
        foodNames: widget.foodNames,
      ),
    );
    if (option == null) return;
    await widget.onSubstitute(
      mealId: meal.id,
      itemIndex: index,
      option: option,
      itemOrder: substitutions.order,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = widget.plan;
    final meals = activeMeals(plan);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_date(plan.periodStart)} a ${_date(plan.periodEnd)}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          plan.isConfirmed ? 'Plano confirmado' : 'Aguardando confirmação',
          style: theme.textTheme.titleMedium,
        ),
        if (!plan.isConfirmed) ...[
          const SizedBox(height: 4),
          Text(
            'Confirme até ${_dateTime(plan.confirmationDeadline)}.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.isSaving ? null : widget.onConfirm,
            child: widget.isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirmar plano'),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.isSaving ? null : _confirmDelete,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir plano'),
          ),
        ),
        const SizedBox(height: 12),
        Text('DIAS DO PLANO', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (meals.isEmpty)
          const _EmptyCard(message: 'Este plano ainda não tem refeições.'),
        if (meals.isNotEmpty) ...[
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:
                  widget.plan.periodEnd
                      .difference(widget.plan.periodStart)
                      .inDays +
                  1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final date = DateTime(
                  widget.plan.periodStart.year,
                  widget.plan.periodStart.month,
                  widget.plan.periodStart.day + index,
                );
                final selected = DateUtils.isSameDay(date, _selectedDate);
                return InkWell(
                  onTap: () => setState(() => _selectedDate = date),
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    width: 54,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weekdayShort(date.weekday),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: selected
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${date.day}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: selected
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          for (final meal in meals.where(
            (meal) => DateUtils.isSameDay(meal.date, _selectedDate),
          )) ...[
            _MealCard(
              meal: meal,
              foodNames: widget.foodNames,
              prescription: widget.prescription,
              enabled: !widget.isSaving,
              onOpenMeal: widget.onOpenMeal,
              onItemTap: (index, item, substitutions) =>
                  _openSubstitution(meal, index, item, substitutions),
            ),
            const SizedBox(height: 10),
          ],
          if (meals.every(
            (meal) => !DateUtils.isSameDay(meal.date, _selectedDate),
          ))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sem refeições neste dia.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.enabled,
    required this.onTap,
  });

  final WeeklyPlan plan;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        child: const Icon(Icons.calendar_today_rounded),
      ),
      title: Text('${_date(plan.periodStart)} a ${_date(plan.periodEnd)}'),
      subtitle: Text(
        plan.isConfirmed ? 'Plano confirmado' : 'Pendente de confirmação',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: enabled ? onTap : null,
    ),
  );
}

/// Plano ativo primeiro (o que cobre hoje; senão o mais recente), depois os
/// anteriores como histórico.
List<WeeklyPlan> _orderedPlans(List<WeeklyPlan> plans) {
  if (plans.length < 2) return plans;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final sorted = [...plans]
    ..sort((a, b) => b.periodStart.compareTo(a.periodStart));
  final active =
      sorted
          .where(
            (plan) =>
                !plan.periodStart.isAfter(today) &&
                !plan.periodEnd.isBefore(today),
          )
          .firstOrNull ??
      sorted.first;
  return [active, ...sorted.where((plan) => plan.id != active.id)];
}

String _foodLabel(Map<String, String> names, String foodId) =>
    names[foodId] ?? 'Alimento';

String _amount(String quantity, String unit) {
  final text = quantity.contains('.')
      ? quantity
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '')
      : quantity;
  return '${text.replaceAll('.', ',')} $unit';
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.foodNames,
    required this.prescription,
    required this.enabled,
    required this.onItemTap,
    this.onOpenMeal,
  });

  final PlannedMeal meal;
  final Map<String, String> foodNames;
  final CurrentPrescription? prescription;
  final bool enabled;
  final Future<void> Function(PlannedMeal meal)? onOpenMeal;
  final void Function(int index, PlannedItem item, ItemSubstitutions options)
  onItemTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 9,
            ),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: const Icon(Icons.restaurant_menu_rounded),
            ),
            title: Text(meal.name),
            subtitle: Text(_mealType(meal.mealType)),
            trailing: onOpenMeal == null
                ? null
                : const Icon(Icons.chevron_right_rounded),
            onTap: onOpenMeal == null ? null : () => onOpenMeal!(meal),
          ),
          for (final (index, item) in meal.items.indexed)
            _ItemRow(
              item: item,
              name: _foodLabel(foodNames, item.foodId),
              substitutions: substitutionsFor(prescription, item),
              enabled: enabled,
              onTap: (substitutions) => onItemTap(index, item, substitutions),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.name,
    required this.substitutions,
    required this.enabled,
    required this.onTap,
  });

  final PlannedItem item;
  final String name;
  final ItemSubstitutions? substitutions;
  final bool enabled;
  final void Function(ItemSubstitutions substitutions) onTap;

  @override
  Widget build(BuildContext context) {
    final options = substitutions;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(name),
      subtitle: Text(
        [
          _amount(item.quantity, item.unit),
          if (item.isSubstituted) 'Com substituição',
        ].join(' · '),
      ),
      trailing: options == null ? null : const Icon(Icons.swap_horiz_rounded),
      onTap: options == null || !enabled ? null : () => onTap(options),
    );
  }
}

class _SubstitutionSheet extends StatefulWidget {
  const _SubstitutionSheet({
    required this.itemName,
    required this.original,
    required this.options,
    required this.foodNames,
  });

  final String itemName;
  final PrescribedFoodRef original;
  final List<SubstitutionOption> options;
  final Map<String, String> foodNames;

  @override
  State<_SubstitutionSheet> createState() => _SubstitutionSheetState();
}

class _SubstitutionSheetState extends State<_SubstitutionSheet> {
  SubstitutionOption? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final original = widget.original;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: RadioGroup<SubstitutionOption>(
          groupValue: _selected,
          onChanged: (value) => setState(() => _selected = value),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Trocar item', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('ORIGINAL', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                '${_foodLabel(widget.foodNames, original.foodId)} · ${_amount(original.quantity, original.unit)}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text('TROCAS AUTORIZADAS', style: theme.textTheme.labelLarge),
              for (final option in widget.options)
                RadioListTile<SubstitutionOption>(
                  contentPadding: EdgeInsets.zero,
                  value: option,
                  title: Text(_foodLabel(widget.foodNames, option.foodId)),
                  subtitle: Text(_amount(option.quantity, option.unit)),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.of(context).pop(_selected),
                child: const Text('Confirmar troca'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _weekdayShort(int weekday) =>
    const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][weekday - 1];

class _PreferenceCard extends StatefulWidget {
  const _PreferenceCard({
    required this.preference,
    required this.isSaving,
    required this.onSave,
  });

  final WeeklyPlanningPreference? preference;
  final bool isSaving;
  final ValueChanged<WeeklyPlanningPreference> onSave;

  @override
  State<_PreferenceCard> createState() => _PreferenceCardState();
}

class _PreferenceCardState extends State<_PreferenceCard> {
  String? _day;
  bool? _enabled;

  static const _days = {
    'MONDAY': 'Segunda-feira',
    'TUESDAY': 'Terça-feira',
    'WEDNESDAY': 'Quarta-feira',
    'THURSDAY': 'Quinta-feira',
    'FRIDAY': 'Sexta-feira',
    'SATURDAY': 'Sábado',
    'SUNDAY': 'Domingo',
  };

  @override
  void didUpdateWidget(covariant _PreferenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preference != oldWidget.preference) {
      _day = null;
      _enabled = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preference = widget.preference;
    if (preference == null) return const SizedBox.shrink();
    final day = _day ?? preference.dayOfWeek;
    final enabled = _enabled ?? preference.enabled;
    final changed =
        day != preference.dayOfWeek || enabled != preference.enabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Geração automática',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha um dia para gerar novos planos automaticamente.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativar geração automática'),
              value: enabled,
              onChanged: widget.isSaving
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(preference.dayOfWeek),
              initialValue: _days.containsKey(day) ? day : null,
              decoration: const InputDecoration(labelText: 'Dia da semana'),
              items: _days.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: widget.isSaving
                  ? null
                  : (value) => setState(() => _day = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: !changed || widget.isSaving
                  ? null
                  : () => widget.onSave(
                      WeeklyPlanningPreference(
                        dayOfWeek: day,
                        enabled: enabled,
                      ),
                    ),
              child: widget.isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar preferência'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: TextStyle(color: scheme.onErrorContainer)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _dateTime(DateTime date) =>
    '${_date(date.toLocal())} às ${date.toLocal().hour.toString().padLeft(2, '0')}:${date.toLocal().minute.toString().padLeft(2, '0')}';

String _mealType(String value) => switch (value) {
  'BREAKFAST' => 'Café da manhã',
  'LUNCH' => 'Almoço',
  'SNACK' => 'Lanche',
  'DINNER' => 'Jantar',
  _ => 'Refeição',
};
