import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:prato_em_dia_mobile/features/planning/domain/substitution_options.dart';
import 'package:prato_em_dia_mobile/features/planning/domain/weekly_plan.dart';
import 'package:prato_em_dia_mobile/features/prescription/domain/current_prescription.dart';
import 'package:prato_em_dia_mobile/features/prescription/domain/current_prescription_repository.dart';
import 'package:prato_em_dia_mobile/features/prescription/presentation/widgets/no_prescription_empty_state.dart';
import 'package:prato_em_dia_mobile/app/theme/app_theme.dart';
import 'package:prato_em_dia_mobile/features/planning/data/weekly_planning_api.dart';
import 'package:prato_em_dia_mobile/features/planning/data/weekly_planning_repository_impl.dart';
import 'package:prato_em_dia_mobile/features/planning/presentation/cubit/weekly_planning_cubit.dart';
import 'package:prato_em_dia_mobile/features/planning/presentation/pages/weekly_planning_page.dart';

void main() {
  test(
    'maps the backend plan and numeric quantity without inventing food names',
    () async {
      final api = _FakeApi();
      final repository = WeeklyPlanningRepositoryImpl(api);
      final plan = (await repository.list()).single;

      expect(plan.id, 'plan-1');
      expect(plan.periodStart, DateTime(2026, 10, 12));
      expect(plan.status, 'PENDING');
      expect(plan.meals.single.name, 'Almoço');
      expect(plan.meals.single.items.single.quantity, '1.5');
      expect((await repository.getPreference()).dayOfWeek, 'MONDAY');
    },
  );

  test('loads, generates and confirms while keeping server data', () async {
    final api = _FakeApi();
    final cubit = WeeklyPlanningCubit(WeeklyPlanningRepositoryImpl(api));

    await cubit.load();
    expect(cubit.state.plans, hasLength(1));
    expect(cubit.state.preference?.enabled, true);

    await cubit.generate();
    expect(cubit.state.selected?.id, 'plan-1');
    expect(cubit.state.selected?.isConfirmed, false);

    await cubit.confirm();
    expect(cubit.state.selected?.isConfirmed, true);
    expect(api.confirmCalls, 1);
    await cubit.confirm();
    expect(api.confirmCalls, 1);
    await cubit.close();
  });

  test('keeps visible plans on refresh failure and permits retry', () async {
    final api = _FakeApi();
    final cubit = WeeklyPlanningCubit(WeeklyPlanningRepositoryImpl(api));
    await cubit.load();
    api.failList = true;
    await cubit.load();
    expect(cubit.state.plans, hasLength(1));
    expect(cubit.state.error, isNotNull);
    api.failList = false;
    await cubit.load();
    expect(cubit.state.error, isNull);
    await cubit.close();
  });

  test('does not emit after the page closes during loading', () async {
    final pending = Completer<List<dynamic>>();
    final api = _FakeApi()..pendingList = pending;
    final cubit = WeeklyPlanningCubit(WeeklyPlanningRepositoryImpl(api));
    final loading = cubit.load();
    await cubit.close();
    pending.complete([api.plan]);
    await loading;
  });

  testWidgets('shows a helpful empty state and manual generation', (
    tester,
  ) async {
    final api = _FakeApi()..emptyList = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WeeklyPlanningPage(repository: WeeklyPlanningRepositoryImpl(api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Você ainda não tem um plano semanal. Gere um plano para começar.',
      ),
      findsOneWidget,
    );
    expect(find.text('Gerar plano semanal'), findsOneWidget);
    await tester.tap(find.text('Gerar plano semanal'));
    await tester.pumpAndSettle();
    expect(find.text('Plano semanal'), findsOneWidget);
  });

  group('PATCH de substituição', () {
    final plan = WeeklyPlan(
      id: 'plan-1',
      prescriptionVersionId: 'version-1',
      planningMode: 'SUBSTITUTIONS_ONLY',
      periodStart: DateTime(2026, 10, 12),
      periodEnd: DateTime(2026, 10, 18),
      confirmationDeadline: DateTime.utc(2026, 10, 11, 12),
      status: 'CONFIRMED',
      version: 4,
      meals: [
        PlannedMeal(
          id: 'meal-1',
          date: DateTime(2026, 10, 12),
          mealType: 'LUNCH',
          name: 'Almoço',
          order: 1,
          items: const [
            PlannedItem(
              id: 'i1',
              foodId: 'arroz',
              quantity: '100.000',
              unit: 'g',
              order: 0,
            ),
            PlannedItem(
              id: 'i2',
              foodId: 'frango',
              quantity: '120',
              unit: 'g',
              order: 1,
            ),
          ],
        ),
        PlannedMeal(
          id: 'meal-2',
          date: DateTime(2026, 10, 13),
          mealType: 'DINNER',
          name: 'Jantar',
          order: 2,
          items: const [
            PlannedItem(id: 'i3', foodId: 'sopa', quantity: '1', unit: 'un'),
          ],
        ),
      ],
    );

    test('troca só o alimento do item e mantém o resto do plano', () {
      final body = buildSubstitutionPatchBody(
        plan,
        mealId: 'meal-1',
        itemIndex: 1,
        option: const SubstitutionOption(
          foodId: 'peixe',
          foodPortionId: 'porcao-9',
          quantity: '110.5',
          unit: 'g',
          allowedSubstitutionId: 'sub-1',
        ),
        itemOrder: 1,
      );
      expect(body['version'], 4);
      final meals = body['meals'] as List;
      expect(meals, hasLength(2));
      expect(meals[0], {
        'id': 'meal-1',
        'date': '2026-10-12',
        'mealType': 'LUNCH',
        'name': 'Almoço',
        'order': 1,
        'items': [
          {
            'id': 'i1',
            'foodId': 'arroz',
            'foodPortionId': null,
            'quantity': 100,
            'unit': 'g',
            'order': 0,
          },
          {
            'id': 'i2',
            'foodId': 'peixe',
            'foodPortionId': 'porcao-9',
            'quantity': 110.5,
            'unit': 'g',
            'order': 1,
          },
        ],
      });
      // Outra refeição vai inalterada, no mesmo dia e na mesma ordem.
      expect((meals[1] as Map)['date'], '2026-10-13');
      expect(((meals[1] as Map)['items'] as List).single['foodId'], 'sopa');
    });

    test('opções vêm só das substituições autorizadas da prescrição', () {
      const prescription = CurrentPrescription(
        id: 'version-1',
        number: 1,
        createdByUserId: null,
        meals: [
          PrescribedMeal(
            id: 'pm',
            name: 'Almoço',
            mealType: 'LUNCH',
            order: 1,
            items: [
              PrescribedItem(
                id: 'pitem-frango',
                foodId: 'frango',
                quantity: '120',
                unit: 'g',
                order: 1,
                substitutions: [
                  AllowedSubstitution(
                    id: 'sub-1',
                    foodId: 'peixe',
                    quantity: '110',
                    unit: 'g',
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      const item = PlannedItem(
        foodId: 'frango',
        quantity: '120',
        unit: 'g',
        prescribedMealItemId: 'pitem-frango',
      );
      final result = substitutionsFor(prescription, item)!;
      expect(result.original.foodId, 'frango');
      expect(result.options.map((o) => o.foodId), ['peixe']);
      expect(result.order, 1);
      const substituted = PlannedItem(
        foodId: 'peixe',
        quantity: '110',
        unit: 'g',
        prescribedMealItemId: 'pitem-frango',
        allowedSubstitutionId: 'sub-1',
      );
      // Já trocado: só resta voltar ao original.
      expect(
        substitutionsFor(prescription, substituted)!.options.single.foodId,
        'frango',
      );
      expect(
        substitutionsFor(
          prescription,
          const PlannedItem(foodId: 'x', quantity: '1', unit: 'g'),
        ),
        isNull,
      );
      expect(substitutionsFor(null, item), isNull);
    });

    test('activeMeals nunca repete dia e categoria', () {
      final duplicated = WeeklyPlan(
        id: 'p',
        prescriptionVersionId: 'v',
        planningMode: 'FREE',
        periodStart: DateTime(2026, 10, 12),
        periodEnd: DateTime(2026, 10, 18),
        confirmationDeadline: DateTime.utc(2026, 10, 11),
        status: 'PENDING',
        version: 0,
        meals: [
          for (final id in ['velha', 'nova'])
            PlannedMeal(
              id: id,
              date: DateTime(2026, 10, 12),
              mealType: 'LUNCH',
              name: id,
              order: 1,
              items: const [],
            ),
        ],
      );
      expect(activeMeals(duplicated).map((m) => m.id), ['nova']);
    });
  });

  group('erros do planejamento', () {
    DioException envelope(int status, String code) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: {'status': status, 'code': code, 'message': 'srv', 'errors': []},
      ),
    );

    test(
      '409 de geração concorrente recarrega o plano com a mensagem',
      () async {
        final api = _FakeApi()
          ..generateError = envelope(409, 'WEEKLY_PLAN_GENERATION_CONFLICT');
        final cubit = WeeklyPlanningCubit(WeeklyPlanningRepositoryImpl(api));
        await cubit.load();
        final loads = api.listCalls;
        await cubit.generate();
        expect(api.listCalls, greaterThan(loads));
        expect(
          cubit.state.error,
          'O plano está sendo gerado agora. Atualize em instantes.',
        );
        expect(cubit.state.noPrescription, false);
        await cubit.close();
      },
    );

    test(
      '404 WEEKLY_PLAN_NOT_FOUND na geração leva ao estado sem prescrição',
      () async {
        final api = _FakeApi()
          ..emptyList = true
          ..generateError = envelope(404, 'WEEKLY_PLAN_NOT_FOUND');
        final cubit = WeeklyPlanningCubit(WeeklyPlanningRepositoryImpl(api));
        await cubit.load();
        await cubit.generate();
        expect(cubit.state.noPrescription, true);
        expect(cubit.state.error, isNull);
        await cubit.close();
      },
    );

    test('recusa do PATCH mostra a mensagem e recarrega', () async {
      final api = _FakeApi()..updateError = envelope(400, 'INVALID_PLANNING');
      final cubit = WeeklyPlanningCubit(WeeklyPlanningRepositoryImpl(api));
      await cubit.load();
      await cubit.select('plan-1');
      final loads = api.listCalls;
      await cubit.substituteItem(
        mealId: 'meal-1',
        itemIndex: 0,
        option: const SubstitutionOption(
          foodId: 'food-2',
          quantity: '1',
          unit: 'porção',
        ),
        itemOrder: 0,
      );
      expect(cubit.state.error, contains('prescrição'));
      expect(api.listCalls, greaterThan(loads));
      await cubit.close();
    });

    test('409 PLANNING_CONFLICT do PATCH recarrega', () async {
      final api = _FakeApi()..updateError = envelope(409, 'PLANNING_CONFLICT');
      final cubit = WeeklyPlanningCubit(WeeklyPlanningRepositoryImpl(api));
      await cubit.load();
      await cubit.select('plan-1');
      final loads = api.listCalls;
      await cubit.substituteItem(
        mealId: 'meal-1',
        itemIndex: 0,
        option: const SubstitutionOption(
          foodId: 'food-2',
          quantity: '1',
          unit: 'porção',
        ),
        itemOrder: 0,
      );
      expect(cubit.state.error, isNotNull);
      expect(api.listCalls, greaterThan(loads));
      await cubit.close();
    });
  });

  group('tela da semana', () {
    Future<void> pumpPage(
      WidgetTester tester,
      _FakeApi api, {
      CurrentPrescriptionRepository? prescriptions,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WeeklyPlanningPage(
            repository: WeeklyPlanningRepositoryImpl(api),
            prescriptionRepository: prescriptions,
            foodNames: (id) async => {
              'food-1': 'Frango grelhado',
              'food-2': 'Peixe assado',
              'food-3': 'Ovo mexido',
            }[id],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('troca mostra só substituições autorizadas e confirma', (
      tester,
    ) async {
      final api = _FakeApi();
      await pumpPage(
        tester,
        api,
        prescriptions: _FakePrescriptions(_prescription),
      );
      await tester.tap(find.textContaining('12/10/2026 a 18/10/2026'));
      await tester.pumpAndSettle();
      expect(find.text('Frango grelhado'), findsOneWidget);

      await tester.tap(find.text('Frango grelhado'));
      await tester.pumpAndSettle();
      expect(find.text('ORIGINAL'), findsOneWidget);
      expect(find.text('Peixe assado'), findsOneWidget);
      expect(find.text('Ovo mexido'), findsOneWidget);
      // Alimento fora da lista autorizada não aparece.
      expect(find.text('Alimento'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar troca'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Peixe assado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar troca'));
      await tester.pumpAndSettle();

      final item =
          ((api.lastPatch!['meals'] as List).single['items'] as List).single
              as Map;
      expect(item['foodId'], 'food-2');
      expect(item['quantity'], 100);
      expect(item['id'], 'item-1');
      expect(api.lastPatch!['version'], 0);
    });

    testWidgets('exclusão pede confirmação antes de chamar o DELETE', (
      tester,
    ) async {
      final api = _FakeApi();
      await pumpPage(
        tester,
        api,
        prescriptions: _FakePrescriptions(_prescription),
      );
      await tester.tap(find.textContaining('12/10/2026 a 18/10/2026'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Excluir plano'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir plano?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.deleteCalls, 0);

      await tester.tap(find.text('Excluir plano'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(api.deleteCalls, 1);
      // Recarregou a lista, já sem o plano.
      expect(find.textContaining('12/10/2026 a 18/10/2026'), findsNothing);
    });

    testWidgets('sem prescrição: estado vazio e sem ação de regenerar', (
      tester,
    ) async {
      final api = _FakeApi()..emptyList = true;
      await pumpPage(tester, api, prescriptions: _FakePrescriptions(null));
      expect(find.byType(NoPrescriptionEmptyState), findsOneWidget);
      expect(find.text('Gerar plano semanal'), findsNothing);
      expect(find.text('Regenerar plano'), findsNothing);
    });

    testWidgets('sem prescrição mas com plano: lista o plano sem regenerar', (
      tester,
    ) async {
      final api = _FakeApi();
      await pumpPage(tester, api, prescriptions: _FakePrescriptions(null));
      expect(find.textContaining('12/10/2026 a 18/10/2026'), findsOneWidget);
      expect(find.text('Regenerar plano'), findsNothing);
      expect(find.byType(NoPrescriptionEmptyState), findsNothing);
    });
  });
}

const _prescription = CurrentPrescription(
  id: 'version-1',
  number: 1,
  createdByUserId: null,
  meals: [
    PrescribedMeal(
      id: 'pm',
      name: 'Almoço',
      mealType: 'LUNCH',
      order: 0,
      items: [
        PrescribedItem(
          id: 'pitem-1',
          foodId: 'food-1',
          quantity: '1.5',
          unit: 'porção',
          order: 0,
          substitutions: [
            AllowedSubstitution(
              id: 'sub-1',
              foodId: 'food-2',
              quantity: '100',
              unit: 'porção',
            ),
            AllowedSubstitution(
              id: 'sub-2',
              foodId: 'food-3',
              quantity: '2',
              unit: 'un',
            ),
          ],
        ),
      ],
    ),
  ],
);

class _FakePrescriptions implements CurrentPrescriptionRepository {
  _FakePrescriptions(this.value);
  final CurrentPrescription? value;

  @override
  Future<CurrentPrescription?> fetchCurrent() async => value;

  @override
  Future<String?> suggestedTimeFor(String mealType) async => null;
}

class _FakeApi implements WeeklyPlanningRemoteDataSource {
  bool failList = false;
  bool emptyList = false;
  Completer<List<dynamic>>? pendingList;
  int confirmCalls = 0;

  Map<String, dynamic> get plan => {
    'id': 'plan-1',
    'prescriptionVersionId': 'version-1',
    'planningMode': 'RESTRICTED',
    'periodStart': '2026-10-12',
    'periodEnd': '2026-10-18',
    'confirmationDeadline': '2026-10-11T12:00:00Z',
    'status': confirmCalls == 0 ? 'PENDING' : 'CONFIRMED',
    'version': confirmCalls,
    'meals': [
      {
        'id': 'meal-1',
        'date': '2026-10-12',
        'mealType': 'LUNCH',
        'name': 'Almoço',
        'order': 0,
        'items': [
          {
            'id': 'item-1',
            'prescribedMealItemId': 'pitem-1',
            'allowedSubstitutionId': null,
            'foodId': 'food-1',
            'foodPortionId': null,
            'quantity': 1.5,
            'unit': 'porção',
            'order': 0,
          },
        ],
      },
    ],
  };

  @override
  Future<List<dynamic>> list() async {
    listCalls++;
    if (pendingList != null) return pendingList!.future;
    if (failList) throw const FormatException('bad data');
    return emptyList ? [] : [plan];
  }

  @override
  Future<Map<String, dynamic>> get(String planId) async => plan;

  @override
  Future<Map<String, dynamic>> generate() async {
    if (generateError != null) throw generateError!;
    emptyList = false;
    return plan;
  }

  @override
  Future<Map<String, dynamic>> confirm(String planId) async {
    confirmCalls++;
    return plan;
  }

  Object? generateError;
  Object? updateError;
  Object? deleteError;
  int listCalls = 0;
  int deleteCalls = 0;
  Map<String, dynamic>? lastPatch;

  @override
  Future<Map<String, dynamic>> update(
    String planId,
    Map<String, dynamic> body,
  ) async {
    if (updateError != null) throw updateError!;
    lastPatch = body;
    return plan;
  }

  @override
  Future<void> delete(String planId) async {
    if (deleteError != null) throw deleteError!;
    deleteCalls++;
    emptyList = true;
  }

  @override
  Future<Map<String, dynamic>> getPreference() async => {
    'patientId': 'patient-1',
    'dayOfWeek': 'MONDAY',
    'enabled': true,
  };

  @override
  Future<Map<String, dynamic>> updatePreference({
    required String dayOfWeek,
    required bool enabled,
  }) async => {
    'patientId': 'patient-1',
    'dayOfWeek': dayOfWeek,
    'enabled': enabled,
  };
}
