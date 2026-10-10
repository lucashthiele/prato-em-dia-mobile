import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_environment.dart';
import '../../../auth/domain/auth_session.dart';
import '../../data/today_api.dart';
import '../../data/today_repository_impl.dart';
import '../../domain/today_repository.dart';
import '../cubit/today_cubit.dart';

/// Today receives the active session and its existing renewal operation from
/// the app shell. [repository] is optional for tests and feature composition.
class TodayPage extends StatefulWidget {
  const TodayPage({
    required this.onLogout,
    this.session,
    this.renewSession,
    this.repository,
    super.key,
  });

  final Future<void> Function() onLogout;
  final AuthSession? session;
  final Future<AuthSession?> Function()? renewSession;
  final TodayRepository? repository;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late final TodayCubit _cubit;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _choose(TodayMeal meal) async {
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
      appBar: AppBar(
        title: const Text('Hoje'),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: SafeArea(
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Text(
                    _todayLabel(DateTime.now()),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Suas refeições planejadas para hoje',
                    style: Theme.of(context).textTheme.bodyLarge,
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
                  const SizedBox(height: 20),
                  if (data.meals.isEmpty)
                    const _Status(
                      icon: Icons.event_busy_outlined,
                      message: 'Nenhuma refeição planejada para hoje.',
                    )
                  else
                    ...data.meals.map((meal) {
                      final event = data.latestEvents[meal.id];
                      final saving = state.savingMealId == meal.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _mealLabel(meal),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  meal.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${meal.itemCount} ${meal.itemCount == 1 ? 'item planejado' : 'itens planejados'}',
                                ),
                                const SizedBox(height: 12),
                                if (event != null)
                                  Text(
                                    'Último registro: ${_eventLabel(event.type)}',
                                  )
                                else
                                  const Text('Ainda não registrada'),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: state.savingMealId == null
                                      ? () => _choose(meal)
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: saving
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          event == null
                                              ? 'Registrar refeição'
                                              : 'Registrar novamente',
                                        ),
                                ),
                              ],
                            ),
                          ),
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

String _mealLabel(TodayMeal meal) {
  final time = meal.time;
  if (time == null || time.isEmpty) return _mealType(meal.mealType);
  return '${_mealType(meal.mealType)} · ${_shortTime(time)}';
}

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
