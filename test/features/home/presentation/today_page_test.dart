import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/app/theme/app_theme.dart';
import 'package:prato_em_dia_mobile/features/home/domain/today_repository.dart';
import 'package:prato_em_dia_mobile/features/home/presentation/pages/today_page.dart';

void main() {
  testWidgets('shows API meals and saves a completion event', (tester) async {
    final repository = _FakeTodayRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TodayPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Almoço de hoje'), findsOneWidget);
    expect(find.text('Ainda não registrada'), findsOneWidget);
    expect(find.text('Registrar'), findsNothing);
    await tester.tap(find.text('Almoço de hoje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Realizada como planejada'));
    await tester.pumpAndSettle();

    expect(repository.recorded, CompletionType.completed);
    expect(find.text('Último registro: realizada'), findsOneWidget);
  });

  testWidgets('shows the daily macro summary instead of the meal count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TodayPage(repository: _FakeTodayRepository(withSummary: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meta do dia'), findsOneWidget);
    expect(find.text('Seu progresso'), findsNothing);
    expect(find.textContaining('1320'), findsOneWidget);
    expect(find.text('66%'), findsOneWidget);
    expect(find.text('112g / 140g'), findsOneWidget);
    expect(find.text('48g'), findsOneWidget);
    expect(find.text('Prot.'), findsOneWidget);
  });

  testWidgets('shows an empty state without made-up meals', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TodayPage(repository: _FakeTodayRepository(empty: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhuma refeição planejada para este dia.'),
      findsOneWidget,
    );
  });

  testWidgets('shows an unscheduled meal without a time separator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TodayPage(repository: _FakeTodayRepository(withoutTime: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Almoço'), findsOneWidget);
    expect(find.textContaining('Almoço ·'), findsNothing);
  });

  testWidgets('opens a recorded meal from its row on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TodayPage(
          repository: _FakeTodayRepository(
            latestEventType: CompletionType.substituted,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final status = find.text('Último registro: realizada com substituição');
    expect(status, findsOneWidget);
    expect(find.text('Registrar novamente'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(status);
    await tester.pumpAndSettle();
    await tester.tap(status);
    await tester.pumpAndSettle();
    expect(find.text('Registrar refeição'), findsOneWidget);
  });
}

class _FakeTodayRepository implements TodayRepository {
  _FakeTodayRepository({
    this.empty = false,
    this.withoutTime = false,
    this.latestEventType,
    this.withSummary = false,
  });

  final bool empty;
  final bool withoutTime;
  final bool withSummary;
  final CompletionType? latestEventType;
  CompletionType? recorded;

  @override
  Future<TodayData> load(DateTime date) async => TodayData(
    summary: withSummary
        ? const DailySummary(
            prescribed: {
              'energy_kcal': NutrientAmount(2000, 'kcal'),
              'protein': NutrientAmount(140, 'g'),
            },
            realized: {
              'energy_kcal': NutrientAmount(1320, 'kcal'),
              'protein': NutrientAmount(112, 'g'),
              'lipids': NutrientAmount(48, 'g'),
            },
          )
        : null,
    meals: empty
        ? []
        : [
            TodayMeal(
              id: 'meal-1',
              name: 'Almoço de hoje',
              mealType: 'LUNCH',
              date: '2026-10-10',
              time: withoutTime ? null : '12:30:00',
              order: 1,
              itemCount: 2,
            ),
          ],
    latestEvents: latestEventType == null
        ? const {}
        : {
            'meal-1': CompletionEvent(
              plannedMealId: 'meal-1',
              type: latestEventType!,
              occurredAt: DateTime(2026, 10, 13),
              createdAt: DateTime(2026, 10, 13),
            ),
          },
    availablePeriods: [
      TodayPeriod(
        start: DateTime.utc(date.year, 1, 1),
        end: DateTime.utc(date.year, 12, 31),
      ),
    ],
  );

  @override
  Future<CompletionEvent> record(TodayMeal meal, CompletionType type) async {
    recorded = type;
    return CompletionEvent(
      plannedMealId: meal.id,
      type: type,
      occurredAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }
}
