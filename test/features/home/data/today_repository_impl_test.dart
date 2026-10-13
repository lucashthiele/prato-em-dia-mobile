import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_session.dart';
import 'package:prato_em_dia_mobile/features/home/data/today_api.dart';
import 'package:prato_em_dia_mobile/features/home/data/today_repository_impl.dart';
import 'package:prato_em_dia_mobile/features/home/domain/today_repository.dart';

void main() {
  const session = AuthSession(
    accessToken: 'token',
    tokenType: 'Bearer',
    expiresIn: 3600,
    passwordChangeRequired: false,
  );

  test(
    'filters today meals and derives status from the day executions',
    () async {
      final api = _FakeApi();
      final repository = TodayRepositoryImpl(api, session, () async => session);
      final data = await repository.load(DateTime(2026, 10, 10));
      expect(data.meals.map((meal) => meal.name), ['Almoço']);
      expect(data.latestEvents['meal-1']?.type, CompletionType.notCompleted);
      expect(api.dates, ['2026-10-10']);
    },
  );

  test(
    'retries an uncertain command with the same key and timestamp',
    () async {
      final api = _FakeApi()
        ..failFirstRecord = true
        ..recorded = true;
      final repository = TodayRepositoryImpl(api, session, () async => session);
      final meal = (await repository.load(DateTime(2026, 10, 10))).meals.single;
      await expectLater(
        repository.record(meal, CompletionType.completed),
        throwsA(isA<TodayFailure>()),
      );
      final event = await repository.record(meal, CompletionType.completed);
      expect(event.type, CompletionType.completed);
      expect(api.keys.length, 2);
      expect(api.keys[0], api.keys[1]);
      expect(api.payloads[0], api.payloads[1]);
      expect(api.payloads[0]['items'], [
        {
          'foodId': 'food-1',
          'portionId': 'portion-1',
          'unit': 'g',
          'quantity': 100,
          'multiplier': 1,
          'plannedItemId': 'item-1',
        },
      ]);
    },
  );

  test('loads the daily nutrition summary and tolerates its failure', () async {
    final repository = TodayRepositoryImpl(
      _FakeApi(),
      session,
      () async => session,
    );
    final summary = (await repository.load(DateTime(2026, 10, 10))).summary!;
    expect(summary.prescribed['energy_kcal']?.amount, 2000);
    expect(summary.prescribed['protein']?.unit, 'g');
    expect(summary.realized['energy_kcal']?.amount, 1320.5);

    final failing = TodayRepositoryImpl(
      _FakeApi()..summaryFails = true,
      session,
      () async => session,
    );
    final data = await failing.load(DateTime(2026, 10, 10));
    expect(data.summary, isNull);
    expect(data.meals, isNotEmpty);
  });

  test('keeps a valid meal whose scheduled time is null', () async {
    final api = _FakeApi()..nullTime = true;
    final repository = TodayRepositoryImpl(api, session, () async => session);
    final data = await repository.load(DateTime(2026, 10, 10));
    expect(data.meals.single.name, 'Almoço');
    expect(data.meals.single.time, isNull);
  });
}

class _FakeApi implements TodayRemoteDataSource {
  final dates = <String>[];
  final keys = <String>[];
  final payloads = <Map<String, dynamic>>[];
  bool failFirstRecord = false;
  bool nullTime = false;
  bool recorded = false;
  bool summaryFails = false;

  @override
  Future<List<dynamic>> plans(String authorization) async => [
    {
      'periodStart': '2026-10-10',
      'periodEnd': '2026-10-16',
      'meals': [
        {
          'id': 'meal-1',
          'date': '2026-10-10',
          'time': nullTime ? null : '12:30:00',
          'mealType': 'LUNCH',
          'name': 'Almoço',
          'order': 1,
          'items': [{}, {}],
        },
        {
          'id': 'meal-2',
          'date': '2026-10-11',
          'time': '08:00:00',
          'mealType': 'BREAKFAST',
          'name': 'Amanhã',
          'order': 1,
          'items': [],
        },
      ],
    },
  ];

  @override
  Future<Map<String, dynamic>> dailySummary(
    String authorization,
    String date,
  ) async {
    if (summaryFails) {
      throw DioException(requestOptions: RequestOptions(path: 'summary'));
    }
    return {
      'date': date,
      'prescribed': {
        'energy_kcal': {'amount': 2000, 'unit': 'kcal'},
        'protein': {'amount': 140, 'unit': 'g'},
      },
      'planned': <String, dynamic>{},
      'realized': {
        'energy_kcal': {'amount': 1320.5, 'unit': 'kcal'},
      },
    };
  }

  @override
  Future<List<dynamic>> executions(String authorization, String date) async {
    dates.add(date);
    return [
      {
        'id': 'exec-other',
        'version': 1,
        'plannedMealId': 'other-meal',
        'items': [{}],
        'createdAt': '2026-10-09T15:00:00Z',
        'updatedAt': '2026-10-09T15:01:00Z',
      },
      if (!recorded)
        {
          'id': 'exec-1',
          'version': 1,
          'plannedMealId': 'meal-1',
          'items': <dynamic>[],
          'createdAt': '2026-10-10T15:00:00Z',
          'updatedAt': '2026-10-10T15:01:00Z',
        },
    ];
  }

  @override
  Future<Map<String, dynamic>> foodLog(
    String authorization,
    String mealId,
  ) async => {
    'plannedMealId': mealId,
    'mode': 'FREE',
    'items': [
      {
        'plannedItemId': 'item-1',
        'catalogFoodId': 'food-1',
        'catalogPortionId': 'portion-1',
        'unit': 'g',
        'quantity': 100,
        'multiplier': 1,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> createExecution(
    String authorization,
    String idempotencyKey,
    Map<String, dynamic> payload,
  ) async {
    keys.add(idempotencyKey);
    payloads.add(payload);
    if (failFirstRecord) {
      failFirstRecord = false;
      throw DioException(requestOptions: RequestOptions(path: 'test'));
    }
    return {
      'id': 'exec-new',
      'version': 1,
      'plannedMealId': payload['plannedMealId'],
      'items': payload['items'],
      'createdAt': '2026-10-10T15:01:00Z',
      'updatedAt': '2026-10-10T15:01:00Z',
    };
  }

  @override
  Future<Map<String, dynamic>> replaceExecution(
    String authorization,
    String id,
    int version,
    String idempotencyKey,
    Map<String, dynamic> payload,
  ) async => createExecution(authorization, idempotencyKey, payload);
}
