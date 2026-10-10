import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/weekly_plan.dart';
import '../../domain/weekly_planning_repository.dart';
import '../cubit/weekly_planning_cubit.dart';

/// A self-contained patient planning page. The host provides an authenticated repository.
class WeeklyPlanningPage extends StatelessWidget {
  const WeeklyPlanningPage({required this.repository, super.key});

  final WeeklyPlanningRepository repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => WeeklyPlanningCubit(repository)..load(),
    child: const _PlanningView(),
  );
}

class _PlanningView extends StatelessWidget {
  const _PlanningView();

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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 92),
                children: [
                  if (state.isLoading) const LinearProgressIndicator(),
                  if (state.error != null) ...[
                    _ErrorPanel(message: state.error!, onRetry: cubit.load),
                    const SizedBox(height: 16),
                  ],
                  if (state.selected == null) ...[
                    Text(
                      'Planeje seus próximos dias',
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
                      'Seus planos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (!state.isLoading && state.plans.isEmpty)
                      const _EmptyCard(
                        message: 'Você ainda não tem um plano semanal. Gere um plano para começar.',
                      ),
                    for (final plan in state.plans) ...[
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minVerticalPadding: 12,
                          title: Text(
                            '${_date(plan.periodStart)} a ${_date(plan.periodEnd)}',
                          ),
                          subtitle: Text(
                            plan.isConfirmed
                                ? 'Confirmado'
                                : 'Pendente de confirmação',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: state.isLoading || state.isSaving
                              ? null
                              : () => cubit.select(plan.id),
                        ),
                      ),
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

class _PlanDetail extends StatelessWidget {
  const _PlanDetail({
    required this.plan,
    required this.isSaving,
    required this.onConfirm,
  });

  final WeeklyPlan plan;
  final bool isSaving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            onPressed: isSaving ? null : onConfirm,
            child: isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirmar plano'),
          ),
        ],
        const SizedBox(height: 24),
        Text('Refeições', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (meals.isEmpty)
          const _EmptyCard(message: 'Este plano ainda não tem refeições.'),
        for (final meal in meals)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_date(meal.date)} · ${_mealType(meal.mealType)}${meal.time == null ? '' : ' · ${meal.time!.substring(0, 5)}'}',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(meal.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${meal.items.length} ${meal.items.length == 1 ? 'item' : 'itens'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

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
