import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/nutrition/macros.dart';
import '../../../food_log/presentation/pages/food_log_page.dart';
import '../../../prescription/data/current_prescription_api.dart';
import '../../../prescription/presentation/widgets/no_prescription_empty_state.dart';
import '../../data/today_api.dart';
import '../../data/today_repository_impl.dart';
import '../../domain/today_repository.dart';
import '../cubit/today_cubit.dart';

/// Pedido de registro de uma categoria (Q2, Q17): a data é a do dia aberto,
/// [plannedMealId] é nulo em `FREE` sem refeição planejada e [suggestedTime]
/// é o horário sugerido da prescrição para a categoria.
class RegisterRequest {
  const RegisterRequest({
    required this.date,
    required this.mealType,
    this.plannedMealId,
    this.suggestedTime,
    this.uncoveredPlannedItemIds,
  });

  final String date;
  final String mealType;
  final String? plannedMealId;
  final String? suggestedTime;
  final List<String>? uncoveredPlannedItemIds;
}

const _blockedMessage = 'Seu plano não prevê alimentos para esta refeição.';

/// Today receives the shared [Dio] (cookie session) from the app shell.
/// [repository] and [onRegister] are optional for tests and composition.
class TodayPage extends StatefulWidget {
  const TodayPage({
    this.dio,
    this.repository,
    this.onRegister,
    this.reloadSignal,
    super.key,
  });

  final Dio? dio;
  final TodayRepository? repository;

  /// Cada notificação recarrega o dia aberto sem limpar a tela (o shell avisa
  /// quando o paciente volta ao Início depois de mexer no plano).
  final Listenable? reloadSignal;

  /// Abre o registro; por padrão empilha o [FoodLogPage].
  final Future<void> Function(RegisterRequest request)? onRegister;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late final TodayCubit _cubit;

  @override
  void initState() {
    super.initState();
    final dio = widget.dio;
    _cubit = TodayCubit(
      widget.repository ??
          (dio == null
              ? _UnavailableTodayRepository()
              : TodayRepositoryImpl(
                  TodayApi(dio),
                  CurrentPrescriptionApi(dio),
                )),
    )..load();
    widget.reloadSignal?.addListener(_reload);
  }

  void _reload() {
    if (mounted) _cubit.load();
  }

  @override
  void didUpdateWidget(TodayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadSignal != widget.reloadSignal) {
      oldWidget.reloadSignal?.removeListener(_reload);
      widget.reloadSignal?.addListener(_reload);
    }
  }

  @override
  void dispose() {
    widget.reloadSignal?.removeListener(_reload);
    _cubit.close();
    super.dispose();
  }

  Future<void> _chooseDate(TodayData data) async {
    final calendar = data.calendar;
    final first = calendar?.first;
    final last = calendar?.last(DateTime.now());
    if (calendar == null || first == null || last == null) return;
    final selected = _cubit.date;
    final chosen = await showDatePicker(
      context: context,
      initialDate: calendar.isSelectable(selected) ? selected : first,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: calendar.isSelectable,
      helpText: 'Escolher dia',
    );
    if (chosen == null || !mounted) return;
    await _cubit.load(date: chosen, clearData: true);
  }

  Future<void> _register(DayCategory category) async {
    final request = RegisterRequest(
      date: formatCivilDate(_cubit.date),
      mealType: category.mealType,
      plannedMealId: category.plannedMealId,
      suggestedTime: category.suggestedTime,
      uncoveredPlannedItemIds: category.plannedMealId == null
          ? null
          : category.uncoveredPlannedItemIds,
    );
    final open = widget.onRegister;
    if (open != null) {
      await open(request);
    } else if (widget.dio != null) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => FoodLogPage(
            mealId: request.plannedMealId,
            mealName: _mealType(request.mealType),
            date: request.date,
            mealType: request.mealType,
            suggestedTime: request.suggestedTime,
            uncoveredPlannedItemIds: request.uncoveredPlannedItemIds,
            dio: widget.dio!,
          ),
        ),
      );
    }
    if (mounted) _cubit.load();
  }

  Future<void> _remove(DayExecution execution) async {
    final removed = await _cubit.remove(execution);
    if (removed == null || !mounted) return;
    final window = removed.restoreExpiresAt.difference(DateTime.now());
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Registro removido.'),
        duration: window < const Duration(seconds: 2)
            ? const Duration(seconds: 2)
            : window > const Duration(seconds: 5)
            ? const Duration(seconds: 5)
            : window,
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => _cubit.restore(removed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<TodayCubit, TodayState>(
          builder: (context, state) {
            final data = state.data;
            if (data == null && state.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (data == null) {
              return _Status(
                icon: Icons.wifi_off_outlined,
                message:
                    state.error ?? 'Não foi possível carregar as refeições.',
                action: 'Tentar novamente',
                onPressed: _cubit.load,
              );
            }
            return RefreshIndicator(
              onRefresh: _cubit.load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  28,
                  20,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _todayLabel(data.date),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seu dia',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Escolher dia',
                        onPressed: data.calendar?.isEmpty == false
                            ? () => _chooseDate(data)
                            : null,
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ],
                  ),
                  if (state.loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    _Message(state.error!, onRetry: _cubit.load),
                  ],
                  if (state.actionError != null) ...[
                    const SizedBox(height: 12),
                    _Message(state.actionError!),
                  ],
                  if (data.noPrescription)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: NoPrescriptionEmptyState(),
                    )
                  else ...[
                    const SizedBox(height: 24),
                    data.summary == null
                        ? _DayProgress(data: data)
                        : _DaySummaryCard(data: data, summary: data.summary!),
                    const SizedBox(height: 28),
                    Text(
                      'REFEIÇÕES',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final category in data.categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CategoryCard(
                          category: category,
                          busy: state.busy,
                          onRegister: () => _register(category),
                          onRemove: _remove,
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _UnavailableTodayRepository implements TodayRepository {
  static const _message = 'A sessão não está disponível. Entre novamente.';

  @override
  Future<TodayData> load(DateTime date) async =>
      throw const TodayFailure(_message);

  @override
  Future<RemovedExecution> remove(DayExecution execution) async =>
      throw const TodayFailure(_message);

  @override
  Future<void> restore(RemovedExecution removed) async =>
      throw const TodayFailure(_message);
}

/// Categorias que contam para o progresso: as que aceitam registro ou já têm.
Iterable<DayCategory> _countable(TodayData data) =>
    data.categories.where((c) => c.canRegister || c.executions.isNotEmpty);

/// Próxima categoria a registrar: aberta para registro e ainda não Registrada.
DayCategory? _nextCategory(TodayData data) => data.categories
    .where((c) => c.canRegister && c.state != CategoryState.logged)
    .firstOrNull;

String _nextLabel(TodayData data, {DateTime? today}) {
  final countable = _countable(data);
  if (countable.isEmpty) return 'Nenhuma refeição disponível';
  final now = today ?? DateTime.now();
  final day = DateTime(data.date.year, data.date.month, data.date.day);
  if (day.isBefore(DateTime(now.year, now.month, now.day))) {
    // Dia que já passou: não há "próxima" refeição, só o resumo do que foi
    // registrado (o app não julga o que ficou sem registro, Q15).
    final logged = countable
        .where((c) => c.state == CategoryState.logged)
        .length;
    return '$logged de ${countable.length} refeições registradas';
  }
  final next = _nextCategory(data);
  if (next == null) return 'Todas as refeições registradas';
  final time = next.suggestedTime;
  return 'Próxima: ${_mealType(next.mealType)}${time == null ? '' : ' · $time'}';
}

class _DayProgress extends StatelessWidget {
  const _DayProgress({required this.data});

  final TodayData data;

  @override
  Widget build(BuildContext context) {
    final countable = _countable(data).toList();
    final completed = countable
        .where((c) => c.state == CategoryState.logged)
        .length;
    final total = countable.length;
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(34),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu progresso',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.82)),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 16,
            children: [
              Text(
                '$completed / $total',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(color: Colors.white, fontSize: 44),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
            ],
          ),
          Text(
            'refeições registradas',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.82)),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 11,
              backgroundColor: Colors.white.withValues(alpha: 0.28),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _nextLabel(data),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({required this.data, required this.summary});

  final TodayData data;
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soft = Colors.white.withValues(alpha: 0.82);
    final kcal = _Macro.of(summary, 'kcal');
    final progress = kcal.fraction;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(34),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kcal.target == null ? 'Consumido hoje' : 'Meta do dia',
                      style: theme.textTheme.titleMedium?.copyWith(color: soft),
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        text: _grams(kcal.realized),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontSize: 44,
                        ),
                        children: [
                          if (kcal.target != null)
                            TextSpan(
                              text: ' / ${_grams(kcal.target!)}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: soft,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      'kcal',
                      style: theme.textTheme.titleMedium?.copyWith(color: soft),
                    ),
                  ],
                ),
              ),
              if (progress != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Progresso',
                      style: theme.textTheme.titleMedium?.copyWith(color: soft),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(kcal.realized / kcal.target! * 100).round()}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            _Bar(value: progress, height: 11),
          ],
          const SizedBox(height: 20),
          for (final (key, label) in const [
            ('protein', 'Prot.'),
            ('carbs', 'Carb.'),
            ('fat', 'Gord.'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MacroRow(label: label, macro: _Macro.of(summary, key)),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _nextLabel(data),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One nutrient of the day: what was realized and, when prescribed, the target.
class _Macro {
  const _Macro(this.realized, this.target, this.unit);

  factory _Macro.of(DailySummary summary, String macro) {
    final realized = pickMacro(summary.realized, macro);
    final target = pickMacro(summary.prescribed, macro);
    return _Macro(
      realized?.amount ?? 0,
      target != null && target.amount > 0 ? target.amount : null,
      (target ?? realized)?.unit ?? (macro == 'kcal' ? 'kcal' : 'g'),
    );
  }

  final num realized;
  final num? target;
  final String unit;

  /// 0..1 for the bar, or null when there is no target to compare with.
  double? get fraction =>
      target == null ? null : (realized / target!).clamp(0, 1).toDouble();
}

String _grams(num value) => value.round().toString();

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.height});

  final double? value;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: LinearProgressIndicator(
      value: value ?? 0,
      minHeight: height,
      backgroundColor: Colors.white.withValues(alpha: 0.28),
      valueColor: const AlwaysStoppedAnimation(Colors.white),
    ),
  );
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.label, required this.macro});

  final String label;
  final _Macro macro;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Colors.white);
    final unit = macro.unit;
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: style?.copyWith(color: Colors.white.withValues(alpha: 0.82)),
          ),
        ),
        Expanded(child: _Bar(value: macro.fraction, height: 6)),
        const SizedBox(width: 12),
        SizedBox(
          width: 96,
          child: Text(
            macro.target == null
                ? '${_grams(macro.realized)}$unit'
                : '${_grams(macro.realized)}$unit / ${_grams(macro.target!)}$unit',
            textAlign: TextAlign.right,
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

String _stateLabel(CategoryState state) => switch (state) {
  CategoryState.logged => 'Registrada',
  CategoryState.partial => 'Parcial',
  CategoryState.notLogged => 'Sem registro',
};

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: foreground),
    ),
  );
}

/// Uma das quatro categorias do dia (Q2). Bloqueada (Q16): desabilitada, sem
/// botão de registro. O estado é o do servidor (M-03).
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.busy,
    required this.onRegister,
    required this.onRemove,
  });

  final DayCategory category;
  final bool busy;
  final VoidCallback onRegister;
  final void Function(DayExecution execution) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final blocked = !category.canRegister;
    final logged = category.state == CategoryState.logged;
    return Card(
      key: ValueKey('category-${category.mealType}'),
      color: blocked ? scheme.surfaceContainerLow : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _mealType(category.mealType),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: blocked ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                ),
                _Chip(
                  _stateLabel(category.state),
                  background: logged
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  foreground: logged
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ],
            ),
            if (category.withSubstitution) ...[
              const SizedBox(height: 8),
              _Chip(
                'Com substituição',
                background: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
              ),
            ],
            if (category.hasPlannedItems) ...[
              const SizedBox(height: 6),
              Text(
                '${category.coveredItemCount} de ${category.coveredItemCount + category.uncoveredItemCount} itens planejados registrados',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (blocked) ...[
              const SizedBox(height: 6),
              Text(
                _blockedMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            for (final execution in category.executions)
              _ExecutionRow(
                execution: execution,
                onRemove: busy ? null : () => onRemove(execution),
              ),
            if (!blocked) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: busy ? null : onRegister,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    category.executions.isEmpty
                        ? 'Registrar'
                        : 'Registrar outro',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExecutionRow extends StatelessWidget {
  const _ExecutionRow({required this.execution, required this.onRemove});

  final DayExecution execution;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = execution.itemCount;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${execution.time == null ? '' : '${execution.time} · '}$count ${count == 1 ? 'item' : 'itens'}${execution.withSubstitution ? ' · com substituição' : ''}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: 'Remover registro',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.message, {this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
        ],
      ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({
    required this.icon,
    required this.message,
    this.action,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 36,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (action != null && onPressed != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onPressed, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

String _mealType(String type) => switch (type) {
  'BREAKFAST' => 'Café da manhã',
  'LUNCH' => 'Almoço',
  'SNACK' => 'Lanche',
  'DINNER' => 'Jantar',
  _ => 'Refeição',
};

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
