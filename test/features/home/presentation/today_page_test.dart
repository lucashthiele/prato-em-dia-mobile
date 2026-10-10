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
        home: TodayPage(onLogout: () async {}, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Almoço de hoje'), findsOneWidget);
    expect(find.text('Ainda não registrada'), findsOneWidget);
    await tester.tap(find.text('Registrar refeição'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Realizada como planejada'));
    await tester.pumpAndSettle();

    expect(repository.recorded, CompletionType.completed);
    expect(find.text('Último registro: realizada'), findsOneWidget);
  });

  testWidgets('shows an empty state without made-up meals', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TodayPage(
          onLogout: () async {},
          repository: _FakeTodayRepository(empty: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma refeição planejada para hoje.'), findsOneWidget);
  });

  testWidgets('shows an unscheduled meal without a time separator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TodayPage(
          onLogout: () async {},
          repository: _FakeTodayRepository(withoutTime: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Almoço'), findsOneWidget);
    expect(find.textContaining('Almoço ·'), findsNothing);
  });
}

class _FakeTodayRepository implements TodayRepository {
  _FakeTodayRepository({this.empty = false, this.withoutTime = false});

  final bool empty;
  final bool withoutTime;
  CompletionType? recorded;

  @override
  Future<TodayData> load(DateTime date) async => TodayData(
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
    latestEvents: const {},
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
