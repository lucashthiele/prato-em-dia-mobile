import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:flutter/material.dart';
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
        'time': '12:30:00',
        'mealType': 'LUNCH',
        'name': 'Almoço',
        'order': 0,
        'items': [
          {'foodId': 'food-1', 'quantity': 1.5, 'unit': 'porção'},
        ],
      },
    ],
  };

  @override
  Future<List<dynamic>> list() async {
    if (pendingList != null) return pendingList!.future;
    if (failList) throw const FormatException('bad data');
    return emptyList ? [] : [plan];
  }

  @override
  Future<Map<String, dynamic>> get(String planId) async => plan;

  @override
  Future<Map<String, dynamic>> generate() async => plan;

  @override
  Future<Map<String, dynamic>> confirm(String planId) async {
    confirmCalls++;
    return plan;
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
