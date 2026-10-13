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
      final periods = <TodayPeriod>[];
      for (final rawPlan in plans) {
        final plan = _object(rawPlan);
        periods.add(
          TodayPeriod(
            start: DateTime.parse(plan['periodStart'] as String),
            end: DateTime.parse(plan['periodEnd'] as String),
          ),
        );
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
              time: meal['time'] as String?,
              order: meal['order'] as int,
              itemCount: (meal['items'] as List<dynamic>).length,
            ),
          );
        }
      }
      meals.sort((a, b) {
        final time = (a.time ?? '').compareTo(b.time ?? '');
        return time != 0 ? time : a.order.compareTo(b.order);
      });
      periods.sort((a, b) => a.start.compareTo(b.start));
      final summary = await _summary(day);
      if (meals.isEmpty) {
        return TodayData(
          meals: const [],
          latestEvents: const {},
          availablePeriods: periods,
          summary: summary,
        );
      }

      final ids = meals.map((meal) => meal.id).toSet();
      final latest = <String, CompletionEvent>{};
      for (final raw in await _authorized((a) => _api.executions(a, day))) {
        final execution = _object(raw);
        final mealId = execution['plannedMealId'] as String?;
        if (mealId != null && ids.contains(mealId)) {
          latest[mealId] = _event(execution);
        }
      }
      return TodayData(
        meals: meals,
        latestEvents: latest,
        availablePeriods: periods,
        summary: summary,
      );
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

  /// The summary is secondary: if it fails the day still loads without it.
  Future<DailySummary?> _summary(String day) async {
    try {
      final data = await _authorized((a) => _api.dailySummary(a, day));
      Map<String, NutrientAmount> totals(Object? raw) => {
        for (final e in (raw as Map<String, dynamic>? ?? const {}).entries)
          e.key: NutrientAmount(
            _amount(_object(e.value)['amount']),
            (_object(e.value)['unit'] as String?) ?? '',
          ),
      };
      return DailySummary(
        prescribed: totals(data['prescribed']),
        planned: totals(data['planned']),
        realized: totals(data['realized']),
      );
    } on DioException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on TodayFailure {
      return null;
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
      final result = await _authorized((auth) async {
        final items = type == CompletionType.completed
            ? await _plannedItems(auth, meal.id)
            : const <Map<String, dynamic>>[];
        final payload = {
          'date': meal.date,
          'plannedMealId': meal.id,
          'items': items,
        };
        final current = (await _api.executions(
          auth,
          meal.date,
        )).map(_object).where((e) => e['plannedMealId'] == meal.id).firstOrNull;
        return current == null
            ? _api.createExecution(auth, command.key, payload)
            : _api.replaceExecution(
                auth,
                current['id'] as String,
                current['version'] as int,
                command.key,
                payload,
              );
      });
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

  /// Consumption identical to the prescription: every planned item as planned.
  Future<List<Map<String, dynamic>>> _plannedItems(
    String auth,
    String mealId,
  ) async {
    final log = await _api.foodLog(auth, mealId);
    return [
      for (final raw in log['items'] as List<dynamic>)
        () {
          final item = _object(raw);
          final portion = item['catalogPortionId'];
          final unit = item['unit'];
          if (portion == null || unit == null) {
            throw const TodayFailure(
              'Abra a refeição para informar porção e quantidade.',
            );
          }
          return {
            'foodId': item['catalogFoodId'],
            'portionId': portion,
            'unit': unit,
            'quantity': item['quantity'],
            'multiplier': item['multiplier'] ?? 1,
            'plannedItemId': item['plannedItemId'],
          };
        }(),
    ];
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

CompletionEvent _event(Map<String, dynamic> data) {
  final items = (data['items'] as List<dynamic>).map(_object).toList();
  return CompletionEvent(
    plannedMealId: data['plannedMealId'] as String,
    type: items.isEmpty
        ? CompletionType.notCompleted
        : items.any((i) => i['allowedSubstitutionId'] != null)
        ? CompletionType.substituted
        : CompletionType.completed,
    occurredAt: DateTime.parse(data['createdAt'] as String),
    createdAt: DateTime.parse(data['updatedAt'] as String),
  );
}

num _amount(Object? value) =>
    value is num ? value : num.tryParse('$value') ?? 0;

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
