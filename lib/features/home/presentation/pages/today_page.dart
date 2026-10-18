import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_environment.dart';
import '../../../auth/domain/auth_session.dart';
import '../../data/today_api.dart';
import '../../data/today_repository_impl.dart';
import '../../../../core/nutrition/macros.dart';
import '../../domain/today_repository.dart';
import '../cubit/today_cubit.dart';
import '../../../food_log/presentation/pages/food_log_page.dart';

/// Today receives the active session and its existing renewal operation from
/// the app shell. [repository] is optional for tests and feature composition.
class TodayPage extends StatefulWidget {
  const TodayPage({
    this.session,
    this.renewSession,
    this.repository,
    super.key,
  });

  final AuthSession? session;
  final Future<AuthSession?> Function()? renewSession;
  final TodayRepository? repository;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late final TodayCubit _cubit;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _cubit = TodayCubit(
      widget.repository ??
          (widget.session == null || widget.renewSession == null
              ? _UnavailableTodayRepository()
              : TodayRepositoryImpl(
                  TodayApi(
                    Dio(
                      BaseOptions(
                        baseUrl: AppEnvironment.apiBaseUrl,
                        connectTimeout: const Duration(seconds: 12),
                        receiveTimeout: const Duration(seconds: 12),
                        headers: const {'Accept': 'application/json'},
                      ),
                    ),
                  ),
                  widget.session!,
                  widget.renewSession!,
                )),
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _chooseDate(TodayData data) async {
    if (data.availablePeriods.isEmpty) return;
    final periods = data.availablePeriods;
    final first = periods
        .map((period) => period.start)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final last = periods
        .map((period) => period.end)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final chosen = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(first) || _selectedDate.isAfter(last)
          ? first
          : _selectedDate,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (day) =>
          periods.any((period) => period.includes(day)),
      helpText: 'Escolher dia do plano',
    );
    if (chosen == null || !mounted) return;
    setState(
      () => _selectedDate = DateTime(chosen.year, chosen.month, chosen.day),
    );
    await _cubit.load(date: _selectedDate, clearData: true);
  }

  Future<void> _choose(TodayMeal meal) async {
    if (widget.session != null && widget.renewSession != null) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => FoodLogPage(
            mealId: meal.id,
            mealName: meal.name,
            date: meal.date,
            mealType: meal.mealType,
            plannedTime: meal.time,
            session: widget.session!,
            renewSession: widget.renewSession!,
          ),
        ),
      );
      if (mounted) _cubit.load();
      return;
    }
    final type = await showModalBottomSheet<CompletionType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Registrar refeição',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(meal.name, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, CompletionType.completed),
                child: const Text('Realizada como planejada'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(context, CompletionType.notCompleted),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Não realizada'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null || !mounted) return;
    final saved = await _cubit.record(meal, type);
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Registro salvo.')));
    }
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
                              _todayLabel(_selectedDate),
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
                        tooltip: 'Escolher dia do plano',
                        onPressed: data.availablePeriods.isNotEmpty
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
                  if (state.mealError != null) ...[
                    const SizedBox(height: 12),
                    _Message(state.mealError!),
                  ],
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
                  if (data.availablePeriods.isEmpty)
                    const _Status(
                      icon: Icons.event_busy_outlined,
                      message:
                          'Você ainda não tem um plano alimentar disponível.',
                    )
                  else if (data.meals.isEmpty)
                    const _Status(
                      icon: Icons.event_busy_outlined,
                      message: 'Nenhuma refeição planejada para este dia.',
                    )
                  else
                    ...data.meals.map((meal) {
                      final event = data.latestEvents[meal.id];
                      final saving = state.savingMealId == meal.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MealCard(
                          meal: meal,
                          event: event,
                          saving: saving,
                          onTap: state.savingMealId == null
                              ? () => _choose(meal)
                              : null,
                        ),
                      );
                    }),
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
  @override
  Future<TodayData> load(DateTime date) async => throw const TodayFailure(
    'A sessão não está disponível. Entre novamente.',
  );

  @override
  Future<CompletionEvent> record(TodayMeal meal, CompletionType type) async =>
      throw const TodayFailure(
        'A sessão não está disponível. Entre novamente.',
      );
}

class _DayProgress extends StatelessWidget {
  const _DayProgress({required this.data});

  final TodayData data;

  @override
  Widget build(BuildContext context) {
    final completed = data.meals.where((meal) {
      final event = data.latestEvents[meal.id];
      return event != null && event.type != CompletionType.notCompleted;
    }).length;
    final total = data.meals.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final next = data.meals
        .where((meal) => data.latestEvents[meal.id] == null)
        .firstOrNull;
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
                    next == null
                        ? 'Todas as refeições registradas'
                        : 'Próxima: ${_mealType(next.mealType)}${next.time == null ? '' : ' · ${_shortTime(next.time!)}'}',
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
    final next = data.meals
        .where((meal) => data.latestEvents[meal.id] == null)
        .firstOrNull;
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
                    data.meals.isEmpty
                        ? 'Nenhuma refeição planejada'
                        : next == null
                        ? 'Todas as refeições registradas'
                        : 'Próxima: ${_mealType(next.mealType)}${next.time == null ? '' : ' · ${_shortTime(next.time!)}'}',
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

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.event,
    required this.saving,
    required this.onTap,
  });

  final TodayMeal meal;
  final CompletionEvent? event;
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = event != null && event!.type != CompletionType.notCompleted;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mealType(meal.mealType),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${meal.time == null ? '' : '${_shortTime(meal.time!)} · '}${meal.itemCount} ${meal.itemCount == 1 ? 'item' : 'itens'}',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      event == null
                          ? 'Ainda não registrada'
                          : 'Último registro: ${_eventLabel(event!.type)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: done ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (saving)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (done)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Feito',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
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

String _eventLabel(CompletionType type) => switch (type) {
  CompletionType.completed => 'realizada',
  CompletionType.notCompleted => 'não realizada',
  CompletionType.substituted => 'realizada com substituição',
};

String _shortTime(String time) =>
    time.length >= 5 ? time.substring(0, 5) : time;

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
