import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/weekly_plan.dart';
import '../../domain/weekly_planning_repository.dart';
import '../cubit/weekly_planning_cubit.dart';

/// A self-contained patient planning page. The host provides an authenticated repository.
class WeeklyPlanningPage extends StatelessWidget {
  const WeeklyPlanningPage({
    required this.repository,
    this.onOpenMeal,
    super.key,
  });

  final WeeklyPlanningRepository repository;
  final Future<void> Function(PlannedMeal meal)? onOpenMeal;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => WeeklyPlanningCubit(repository)..load(),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded),
                      label: const Text('Gerar plano semanal'),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'SEUS PLANOS',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (!state.isLoading && state.plans.isEmpty)
                      const _EmptyCard(
                        message: 'Você ainda não tem um plano semanal. Gere um plano para começar.',
                      ),
                    for (final plan in state.plans) ...[
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            child: const Icon(Icons.calendar_today_rounded),
                          ),
                          title: Text(
                            '${_date(plan.periodStart)} a ${_date(plan.periodEnd)}',
                          ),
                          subtitle: Text(
                            plan.isConfirmed
                                ? 'Plano confirmado'
                                : 'Pendente de confirmação',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: state.isLoading || state.isSaving
                              ? null
                              : () => cubit.select(plan.id),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 20),
                    _PreferenceCard(
                      preference: state.preference,
                      isSaving: state.isSaving,
                      onSave: cubit.updatePreference,
                    ),
                  ] else ...[
                    _PlanDetail(
                      plan: state.selected!,
                      isSaving: state.isSaving,
                      onConfirm: cubit.confirm,
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
    required this.onConfirm,
    this.onOpenMeal,
  });

  final WeeklyPlan plan;
  final bool isSaving;
  final VoidCallback onConfirm;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = widget.plan;
    final meals = [...plan.meals]
      ..sort((a, b) {
        final date = a.date.compareTo(b.date);
        return date != 0 ? date : a.order.compareTo(b.order);
      });
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
        const SizedBox(height: 24),
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
            Card(
              child: ListTile(
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
                subtitle: Text(
                  '${_mealType(meal.mealType)}${meal.time == null ? '' : ' · ${meal.time!.substring(0, 5)}'} · ${meal.items.length} ${meal.items.length == 1 ? 'item' : 'itens'}',
                ),
                trailing: widget.onOpenMeal == null
                    ? null
                    : const Icon(Icons.chevron_right_rounded),
                onTap: widget.onOpenMeal == null
                    ? null
                    : () => widget.onOpenMeal!(meal),
              ),
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
