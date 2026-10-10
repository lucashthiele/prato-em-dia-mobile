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
    'filters today meals and uses the latest event in paged history',
    () async {
      final api = _FakeApi();
      final repository = TodayRepositoryImpl(api, session, () async => session);
      final data = await repository.load(DateTime(2026, 10, 10));
      expect(data.meals.map((meal) => meal.name), ['Almoço']);
      expect(data.latestEvents['meal-1']?.type, CompletionType.notCompleted);
      expect(api.pages, [0, 1]);
    },
  );

  test(
    'retries an uncertain command with the same key and timestamp',
    () async {
      final api = _FakeApi()..failFirstRecord = true;
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
    },
  );
}

class _FakeApi implements TodayRemoteDataSource {
  final pages = <int>[];
  final keys = <String>[];
  final payloads = <Map<String, dynamic>>[];
  bool failFirstRecord = false;

  @override
  Future<List<dynamic>> plans(String authorization) async => [
    {
      'periodStart': '2026-10-10',
      'periodEnd': '2026-10-16',
      'meals': [
        {
          'id': 'meal-1',
          'date': '2026-10-10',
          'time': '12:30:00',
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
  Future<Map<String, dynamic>> events(String authorization, int page) async {
    pages.add(page);
    return {
      'totalPages': 2,
      'content': page == 0
          ? [
              {
                'plannedMealId': 'other-meal',
                'eventType': 'COMPLETED',
                'occurredAt': '2026-10-09T15:00:00Z',
                'createdAt': '2026-10-09T15:01:00Z',
              },
            ]
          : [
              {
                'plannedMealId': 'meal-1',
                'eventType': 'NOT_COMPLETED',
                'occurredAt': '2026-10-10T15:00:00Z',
                'createdAt': '2026-10-10T15:01:00Z',
              },
            ],
    };
  }

  @override
  Future<Map<String, dynamic>> record(
    String authorization,
    String mealId,
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
      'plannedMealId': mealId,
      'eventType': payload['eventType'],
      'occurredAt': payload['occurredAt'],
      'createdAt': '2026-10-10T15:01:00Z',
    };
  }
}
