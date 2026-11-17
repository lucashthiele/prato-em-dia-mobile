import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/home/data/today_api.dart';
import 'package:prato_em_dia_mobile/features/home/data/today_repository_impl.dart';
import 'package:prato_em_dia_mobile/features/home/domain/today_repository.dart';
import 'package:prato_em_dia_mobile/features/prescription/domain/current_prescription.dart';
import 'package:prato_em_dia_mobile/features/prescription/domain/current_prescription_repository.dart';

Map<String, dynamic> category(
  String type,
  String state, {
  bool canRegister = true,
  String? plannedMealId,
  List<String> uncovered = const [],
  int covered = 0,
}) => {
  'mealType': type,
  'state': state,
  'canRegister': canRegister,
  'blockedReason': canRegister ? null : 'NO_ALLOWED_FOODS',
  'plannedMealId': plannedMealId,
  'coveredItemCount': covered,
  'uncoveredItemCount': uncovered.length,
  'coveredPlannedItemIds': <String>[],
  'uncoveredPlannedItemIds': uncovered,
};

void main() {
  test(
    'maps the four categories from the server without computing state',
    () async {
      final api = _FakeApi()
        ..categories = {
          'date': '2026-10-10',
          'categories': [
            category('BREAKFAST', 'LOGGED', plannedMealId: 'm1', covered: 2),
            category(
              'LUNCH',
              'PARTIAL',
              plannedMealId: 'm2',
              covered: 1,
              uncovered: ['i2'],
            ),
            category('SNACK', 'NOT_LOGGED', canRegister: false),
            category('DINNER', 'NOT_LOGGED'),
          ],
        }
        ..executionList = [
          _execution('e2', 'LUNCH', '13:00:00', substitution: true),
          _execution('e1', 'BREAKFAST', '07:30:00'),
          _execution('e3', 'LUNCH', '12:00:00'),
        ];
      final repository = TodayRepositoryImpl(
        api,
        _Prescriptions(_prescription()),
      );

      final data = await repository.load(DateTime(2026, 10, 10));

      expect(api.dates, containsAll(['2026-10-10']));
      expect(data.categories.map((c) => c.mealType), [
        'BREAKFAST',
        'LUNCH',
        'SNACK',
        'DINNER',
      ]);
      expect(data.categories.map((c) => c.state), [
        CategoryState.logged,
        CategoryState.partial,
        CategoryState.notLogged,
        CategoryState.notLogged,
      ]);
      final lunch = data.categories[1];
      expect(lunch.uncoveredPlannedItemIds, ['i2']);
      expect(lunch.plannedMealId, 'm2');
      expect(lunch.executions.map((e) => e.id), ['e3', 'e2']);
      expect(lunch.executions.first.time, '12:00');
      expect(lunch.withSubstitution, isTrue);
      expect(data.categories[0].withSubstitution, isFalse);
      expect(data.categories[2].canRegister, isFalse);
      expect(data.categories[2].blockedReason, 'NO_ALLOWED_FOODS');
      // Free category without a planned meal, suggested time from prescription.
      expect(data.categories[3].plannedMealId, isNull);
      expect(data.categories[3].suggestedTime, '19:30');
      expect(data.categories[0].suggestedTime, isNull);
      expect(data.hasPrescription, isTrue);
      expect(data.noPrescription, isFalse);
    },
  );

  test('maps calendar-periods and only those days are selectable', () async {
    final api = _FakeApi()
      ..calendar = {
        'plans': [
          {
            'planId': 'p1',
            'prescriptionVersionId': 'v1',
            'start': '2026-10-05',
            'end': '2026-10-11',
          },
        ],
        'prescriptions': [
          {
            'prescriptionId': 'x',
            'versionId': 'v1',
            'start': '2026-10-01',
            'end': '2026-10-03',
          },
        ],
        'freeExecutionDates': ['2026-10-20'],
      };
    final data = await TodayRepositoryImpl(
      api,
      _Prescriptions(_prescription()),
    ).load(DateTime(2026, 10, 10));
    final calendar = data.calendar!;
    expect(calendar.plans.single.start, DateTime(2026, 10, 5));
    expect(calendar.freeExecutionDates, [DateTime(2026, 10, 20)]);
    expect(calendar.isSelectable(DateTime(2026, 10, 5)), isTrue);
    expect(calendar.isSelectable(DateTime(2026, 10, 11)), isTrue);
    expect(calendar.isSelectable(DateTime(2026, 10, 2)), isTrue);
    expect(calendar.isSelectable(DateTime(2026, 10, 20)), isTrue);
    expect(calendar.isSelectable(DateTime(2026, 10, 4)), isFalse);
    expect(calendar.isSelectable(DateTime(2026, 10, 12)), isFalse);
    expect(calendar.first, DateTime(2026, 10, 1));
    expect(calendar.last(DateTime(2026, 10, 10)), DateTime(2026, 10, 20));
  });

  test('a failing calendar or summary does not break the day', () async {
    final api = _FakeApi()
      ..calendarFails = true
      ..summaryFails = true;
    final data = await TodayRepositoryImpl(
      api,
      _Prescriptions(_prescription()),
    ).load(DateTime(2026, 10, 10));
    expect(data.calendar, isNull);
    expect(data.summary, isNull);
    expect(data.categories, hasLength(4));
  });

  test('no prescription on a day without plan shows the empty state', () async {
    final api = _FakeApi()
      ..categories = {
        'categories': [
          for (final t in ['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER'])
            category(t, 'NOT_LOGGED', canRegister: false),
        ],
      };
    final data = await TodayRepositoryImpl(
      api,
      _Prescriptions(null),
    ).load(DateTime(2026, 10, 10));
    expect(data.hasPrescription, isFalse);
    expect(data.noPrescription, isTrue);
  });

  test('no prescription but a plan in course keeps the categories', () async {
    final api = _FakeApi()
      ..categories = {
        'categories': [
          category('BREAKFAST', 'NOT_LOGGED', plannedMealId: 'm1'),
          for (final t in ['LUNCH', 'SNACK', 'DINNER'])
            category(t, 'NOT_LOGGED', canRegister: false),
        ],
      };
    final data = await TodayRepositoryImpl(
      api,
      _Prescriptions(null),
    ).load(DateTime(2026, 10, 10));
    expect(data.hasPrescription, isFalse);
    expect(data.noPrescription, isFalse);
  });

  test(
    'a failed prescription lookup does not claim the patient has none',
    () async {
      final api = _FakeApi()
        ..categories = {
          'categories': [
            for (final t in ['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER'])
              category(t, 'NOT_LOGGED', canRegister: false),
          ],
        };
      final data = await TodayRepositoryImpl(
        api,
        _Prescriptions(null, fails: true),
      ).load(DateTime(2026, 10, 10));
      expect(data.noPrescription, isFalse);
    },
  );

  test('remove sends version and key, and restore sends the token', () async {
    final api = _FakeApi();
    final repository = TodayRepositoryImpl(api, _Prescriptions(null));
    const execution = DayExecution(
      id: 'e1',
      version: 3,
      mealType: 'LUNCH',
      time: '12:00',
      itemCount: 1,
      withSubstitution: false,
    );

    final removed = await repository.remove(execution);
    expect(api.deleted.single.id, 'e1');
    expect(api.deleted.single.version, 3);
    expect(api.deleted.single.key, isNotEmpty);
    expect(removed.id, 'e1');
    expect(removed.restoreToken, 'token-1');
    expect(removed.restoreExpiresAt, DateTime.utc(2026, 10, 10, 12, 0, 5));

    await repository.restore(removed);
    expect(api.restored, [('e1', 'token-1')]);
  });

  test('a restore conflict means the undo window closed', () async {
    final api = _FakeApi()..restoreError = _error(409, 'TRACKING_CONFLICT');
    final repository = TodayRepositoryImpl(api, _Prescriptions(null));
    await expectLater(
      repository.restore(
        RemovedExecution(
          id: 'e1',
          restoreToken: 't',
          restoreExpiresAt: DateTime.utc(2026),
        ),
      ),
      throwsA(
        isA<TodayFailure>().having(
          (f) => f.message,
          'message',
          TodayRepositoryImpl.restoreExpiredMessage,
        ),
      ),
    );
  });

  test('server errors become the message of their code', () async {
    final api = _FakeApi();
    final repository = TodayRepositoryImpl(api, _Prescriptions(null));
    api.categoriesError = _error(404, 'TRACKING_NOT_FOUND');
    await expectLater(
      repository.load(DateTime(2026, 10, 10)),
      throwsA(isA<TodayFailure>()),
    );
  });
}

DioException _error(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: {'status': status, 'code': code, 'message': 'x', 'errors': []},
  ),
);

Map<String, dynamic> _execution(
  String id,
  String type,
  String time, {
  bool substitution = false,
}) => {
  'id': id,
  'version': 1,
  'mealType': type,
  'time': time,
  'items': [
    {'foodId': 'f', 'allowedSubstitutionId': substitution ? 'a1' : null},
  ],
};

CurrentPrescription _prescription() => const CurrentPrescription(
  id: 'rx',
  number: 1,
  createdByUserId: null,
  meals: [
    PrescribedMeal(
      id: 'pm',
      name: 'Jantar',
      mealType: 'DINNER',
      order: 1,
      suggestedTime: '19:30',
    ),
  ],
);

class _Prescriptions implements CurrentPrescriptionRepository {
  _Prescriptions(this.current, {this.fails = false});

  final CurrentPrescription? current;
  final bool fails;

  @override
  Future<CurrentPrescription?> fetchCurrent() async {
    if (fails) throw _error(500, 'INTERNAL_ERROR');
    return current;
  }

  @override
  Future<String?> suggestedTimeFor(String mealType) async =>
      current?.suggestedTimeFor(mealType);
}

class _FakeApi implements TodayRemoteDataSource {
  final dates = <String>[];
  final deleted = <({String id, int version, String key})>[];
  final restored = <(String, String)>[];
  bool summaryFails = false;
  bool calendarFails = false;
  DioException? restoreError;
  DioException? categoriesError;
  List<Map<String, dynamic>> executionList = [];
  Map<String, dynamic> calendar = {
    'plans': [],
    'prescriptions': [],
    'freeExecutionDates': [],
  };
  Map<String, dynamic> categories = {
    'categories': [
      for (final t in ['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER'])
        category(t, 'NOT_LOGGED'),
    ],
  };

  @override
  Future<Map<String, dynamic>> dailyMealCategories(String date) async {
    dates.add(date);
    if (categoriesError != null) throw categoriesError!;
    return categories;
  }

  @override
  Future<Map<String, dynamic>> calendarPeriods() async {
    if (calendarFails) throw _error(500, 'INTERNAL_ERROR');
    return calendar;
  }

  @override
  Future<Map<String, dynamic>> dailySummary(String date) async {
    if (summaryFails) throw _error(500, 'INTERNAL_ERROR');
    return {
      'prescribed': {
        'energy_kcal': {'amount': 2000, 'unit': 'kcal'},
      },
      'planned': <String, dynamic>{},
      'realized': <String, dynamic>{},
    };
  }

  @override
  Future<List<dynamic>> executions(String date) async => executionList;

  @override
  Future<Map<String, dynamic>> deleteExecution(
    String id,
    int version,
    String idempotencyKey,
  ) async {
    deleted.add((id: id, version: version, key: idempotencyKey));
    return {
      'id': id,
      'version': version + 1,
      'restoreToken': 'token-1',
      'restoreExpiresAt': '2026-10-10T12:00:05Z',
    };
  }

  @override
  Future<void> restoreExecution(String id, String restoreToken) async {
    if (restoreError != null) throw restoreError!;
    restored.add((id, restoreToken));
  }
}
