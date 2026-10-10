import 'dart:math';

import 'package:dio/dio.dart';

import '../../auth/domain/auth_session.dart';
import '../domain/today_repository.dart';
import 'today_api.dart';

class TodayRepositoryImpl implements TodayRepository {
  TodayRepositoryImpl(this._api, this._session, this._renewSession);

  final TodayRemoteDataSource _api;
  AuthSession _session;
  final Future<AuthSession?> Function() _renewSession;
  final Map<String, _PendingCommand> _pending = {};

  Future<T> _authorized<T>(Future<T> Function(String) request) async {
    try {
      return await request('${_session.tokenType} ${_session.accessToken}');
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      final session = await _renewSession();
      if (session == null) {
        throw const TodayFailure('Sua sessão terminou. Entre novamente.');
      }
      _session = session;
      return request('${session.tokenType} ${session.accessToken}');
    }
  }

  @override
  Future<TodayData> load(DateTime date) async {
    try {
      final plans = await _authorized(_api.plans);
      final day = _civilDate(date);
      final meals = <TodayMeal>[];
      for (final rawPlan in plans) {
        final plan = _object(rawPlan);
        if ((plan['periodStart'] as String).compareTo(day) > 0 ||
            (plan['periodEnd'] as String).compareTo(day) < 0) {
          continue;
        }
        for (final rawMeal in plan['meals'] as List<dynamic>) {
          final meal = _object(rawMeal);
          if (meal['date'] != day) continue;
          meals.add(
            TodayMeal(
              id: meal['id'] as String,
              name: meal['name'] as String,
              mealType: meal['mealType'] as String,
              date: meal['date'] as String,
              time: meal['time'] as String,
              order: meal['order'] as int,
              itemCount: (meal['items'] as List<dynamic>).length,
            ),
          );
        }
      }
      meals.sort((a, b) {
        final time = a.time.compareTo(b.time);
        return time != 0 ? time : a.order.compareTo(b.order);
      });
      if (meals.isEmpty) return const TodayData(meals: [], latestEvents: {});

      // The patient history is newest first. Continue until all today's meals
      // have a latest event or the server has no more pages.
      final ids = meals.map((meal) => meal.id).toSet();
      final latest = <String, CompletionEvent>{};
      var page = 0;
      while (latest.length < ids.length) {
        final result = await _authorized((auth) => _api.events(auth, page));
        final content = result['content'] as List<dynamic>;
        for (final raw in content) {
          final event = _event(_object(raw));
          if (ids.contains(event.plannedMealId)) {
            latest.putIfAbsent(event.plannedMealId, () => event);
          }
        }
        page++;
        if (page >= (result['totalPages'] as int) || content.isEmpty) break;
      }
      return TodayData(meals: meals, latestEvents: latest);
    } on TodayFailure {
      rethrow;
    } on DioException catch (error) {
      throw TodayFailure(_message(error));
    } on FormatException {
      throw const TodayFailure(
        'Não foi possível ler as refeições. Tente novamente.',
      );
    } on TypeError {
      throw const TodayFailure(
        'Não foi possível ler as refeições. Tente novamente.',
      );
    }
  }

  @override
  Future<CompletionEvent> record(TodayMeal meal, CompletionType type) async {
    if (type == CompletionType.substituted) {
      throw const TodayFailure(
        'Para registrar uma substituição, escolha uma alternativa autorizada na prescrição.',
      );
    }
    final existing = _pending[meal.id];
    final command = existing != null && existing.type == type
        ? existing
        : _PendingCommand(type, _newKey(), DateTime.now().toUtc());
    _pending[meal.id] = command;
    try {
      final result = await _authorized(
        (auth) => _api.record(auth, meal.id, command.key, {
          'eventType': _wireType(type),
          'occurredAt': command.occurredAt.toIso8601String(),
          'substitutions': <Object>[],
        }),
      );
      _pending.remove(meal.id);
      return _event(result);
    } on TodayFailure {
      rethrow;
    } on DioException catch (error) {
      throw TodayFailure(_message(error));
    } on FormatException {
      throw const TodayFailure(
        'Não foi possível confirmar o registro. Tente novamente.',
      );
    } on TypeError {
      throw const TodayFailure(
        'Não foi possível confirmar o registro. Tente novamente.',
      );
    }
  }
}

class _PendingCommand {
  const _PendingCommand(this.type, this.key, this.occurredAt);

  final CompletionType type;
  final String key;
  final DateTime occurredAt;
}

String _civilDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _wireType(CompletionType type) => switch (type) {
  CompletionType.completed => 'COMPLETED',
  CompletionType.notCompleted => 'NOT_COMPLETED',
  CompletionType.substituted => 'SUBSTITUTED',
};

CompletionEvent _event(Map<String, dynamic> data) => CompletionEvent(
  plannedMealId: data['plannedMealId'] as String,
  type: switch (data['eventType']) {
    'COMPLETED' => CompletionType.completed,
    'NOT_COMPLETED' => CompletionType.notCompleted,
    'SUBSTITUTED' => CompletionType.substituted,
    _ => throw const FormatException('Tipo de evento inválido.'),
  },
  occurredAt: DateTime.parse(data['occurredAt'] as String),
  createdAt: DateTime.parse(data['createdAt'] as String),
);

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Resposta inválida.');
}

String _message(DioException error) => switch (error.response?.statusCode) {
  400 => 'O registro não foi aceito. Confira a refeição e tente novamente.',
  401 => 'Sua sessão terminou. Entre novamente.',
  403 => 'Você não tem acesso a esta refeição.',
  404 => 'Esta refeição não está mais disponível. Atualize a página.',
  409 => 'A refeição mudou. Atualize a página antes de registrar.',
  int status when status >= 500 =>
    'O serviço está indisponível. Tente novamente em instantes.',
  _ => 'Não foi possível conectar. Verifique sua internet e tente novamente.',
};

String _newKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
