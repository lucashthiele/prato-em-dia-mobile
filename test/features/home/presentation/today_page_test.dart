import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/app/theme/app_theme.dart';
import 'package:prato_em_dia_mobile/features/home/domain/today_repository.dart';
import 'package:prato_em_dia_mobile/features/home/presentation/pages/today_page.dart';
import 'package:prato_em_dia_mobile/features/prescription/presentation/widgets/no_prescription_empty_state.dart';

const _lunchExecution = DayExecution(
  id: 'e1',
  version: 1,
  mealType: 'LUNCH',
  time: '12:30',
  itemCount: 2,
  withSubstitution: true,
);

DayCategory _cat(
  String type,
  CategoryState state, {
  bool canRegister = true,
  String? plannedMealId,
  List<DayExecution> executions = const [],
  String? suggestedTime,
  int covered = 0,
  int uncovered = 0,
}) => DayCategory(
  mealType: type,
  state: state,
  canRegister: canRegister,
  blockedReason: canRegister ? null : 'NO_ALLOWED_FOODS',
  plannedMealId: plannedMealId,
  coveredItemCount: covered,
  uncoveredItemCount: uncovered,
  executions: executions,
  suggestedTime: suggestedTime,
);

Future<void> _pump(WidgetTester tester, TodayPage page) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: page));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the four categories in the three states', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      TodayPage(
        repository: _FakeTodayRepository(
          categories: [
            _cat(
              'BREAKFAST',
              CategoryState.logged,
              plannedMealId: 'm1',
              covered: 2,
            ),
            _cat(
              'LUNCH',
              CategoryState.partial,
              plannedMealId: 'm2',
              executions: const [_lunchExecution],
              covered: 1,
              uncovered: 1,
            ),
            _cat('SNACK', CategoryState.notLogged),
            _cat('DINNER', CategoryState.notLogged),
          ],
        ),
      ),
    );

    for (final name in ['Café da manhã', 'Almoço', 'Lanche', 'Jantar']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Registrada'), findsOneWidget);
    expect(find.text('Parcial'), findsOneWidget);
    expect(find.text('Sem registro'), findsNWidgets(2));
    expect(find.text('Com substituição'), findsOneWidget);
    expect(find.text('Não realizada'), findsNothing);
    expect(find.text('1 de 2 itens planejados registrados'), findsOneWidget);
    expect(find.text('Registrar'), findsNWidgets(3));
    expect(find.text('Registrar outro'), findsOneWidget);
  });

  testWidgets('a blocked category is disabled without a register button', (
    tester,
  ) async {
    await _pump(
      tester,
      TodayPage(
        repository: _FakeTodayRepository(
          categories: [
            _cat('BREAKFAST', CategoryState.notLogged, canRegister: false),
            _cat('LUNCH', CategoryState.notLogged, plannedMealId: 'm'),
          ],
        ),
      ),
    );
    expect(
      find.text('Seu plano não prevê alimentos para esta refeição.'),
      findsOneWidget,
    );
    final blocked = find.byKey(const ValueKey('category-BREAKFAST'));
    expect(
      find.descendant(of: blocked, matching: find.byType(FilledButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: blocked, matching: find.text('Registrar')),
      findsNothing,
    );
    expect(find.text('Registrar'), findsOneWidget);
  });

  testWidgets('no prescription on a day without plan replaces the categories', (
    tester,
  ) async {
    await _pump(
      tester,
      TodayPage(
        repository: _FakeTodayRepository(
          hasPrescription: false,
          categories: [
            for (final t in ['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER'])
              _cat(t, CategoryState.notLogged, canRegister: false),
          ],
        ),
      ),
    );
    expect(find.byType(NoPrescriptionEmptyState), findsOneWidget);
    expect(find.text(NoPrescriptionEmptyState.message), findsOneWidget);
    expect(find.text('Almoço'), findsNothing);
    expect(find.text('Registrar'), findsNothing);
  });

  testWidgets(
    'a day covered by a plan keeps the categories without prescription',
    (tester) async {
      await _pump(
        tester,
        TodayPage(
          repository: _FakeTodayRepository(
            hasPrescription: false,
            categories: [
              _cat('BREAKFAST', CategoryState.notLogged, plannedMealId: 'm1'),
              for (final t in ['LUNCH', 'SNACK', 'DINNER'])
                _cat(t, CategoryState.notLogged, canRegister: false),
            ],
          ),
        ),
      );
      expect(find.byType(NoPrescriptionEmptyState), findsNothing);
      expect(find.text('Café da manhã'), findsOneWidget);
      expect(find.text('Registrar'), findsOneWidget);
    },
  );

  testWidgets(
    'registers a category without planned meal at the suggested time',
    (tester) async {
      RegisterRequest? opened;
      await _pump(
        tester,
        TodayPage(
          repository: _FakeTodayRepository(
            categories: [
              _cat('DINNER', CategoryState.notLogged, suggestedTime: '19:30'),
            ],
          ),
          onRegister: (request) async => opened = request,
        ),
      );
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(opened, isNotNull);
      expect(opened!.mealType, 'DINNER');
      expect(opened!.plannedMealId, isNull);
      expect(opened!.suggestedTime, '19:30');
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(opened!.date), isTrue);
    },
  );

  testWidgets('removes an execution and offers Desfazer', (tester) async {
    final repository = _FakeTodayRepository(
      categories: [
        _cat(
          'LUNCH',
          CategoryState.logged,
          executions: const [_lunchExecution],
        ),
      ],
    );
    await _pump(tester, TodayPage(repository: repository));
    expect(find.text('12:30 · 2 itens · com substituição'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover registro'));
    await tester.pumpAndSettle();
    expect(repository.removed, ['e1']);
    expect(find.text('Registro removido.'), findsOneWidget);
    expect(find.text('Sem registro'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(repository.restored, ['token-e1']);
    expect(find.text('Registrada'), findsOneWidget);
    expect(find.text('12:30 · 2 itens · com substituição'), findsOneWidget);
  });

  testWidgets('only calendar days are selectable', (tester) async {
    await _pump(
      tester,
      TodayPage(
        repository: _FakeTodayRepository(
          categories: [_cat('LUNCH', CategoryState.notLogged)],
          calendar: CalendarPeriods(
            plans: [
              DatePeriod(
                start: DateTime(2026, 10, 5),
                end: DateTime(2026, 10, 12),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Escolher dia'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher dia'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      TodayPage(
        repository: _FakeTodayRepository(
          categories: [
            _cat(
              'LUNCH',
              CategoryState.partial,
              plannedMealId: 'm',
              executions: const [_lunchExecution],
              covered: 1,
              uncovered: 1,
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeTodayRepository implements TodayRepository {
  _FakeTodayRepository({
    required this.categories,
    this.hasPrescription = true,
    this.calendar,
  });

  List<DayCategory> categories;
  final bool hasPrescription;
  final CalendarPeriods? calendar;
  final removed = <String>[];
  final restored = <String>[];
  final _hidden = <String>{};

  @override
  Future<TodayData> load(DateTime date) async => TodayData(
    date: DateTime(date.year, date.month, date.day),
    hasPrescription: hasPrescription,
    calendar: calendar,
    categories: [
      for (final c in categories)
        if (c.executions.any((e) => _hidden.contains(e.id)))
          DayCategory(
            mealType: c.mealType,
            state: CategoryState.notLogged,
            canRegister: c.canRegister,
            plannedMealId: c.plannedMealId,
          )
        else
          c,
    ],
  );

  @override
  Future<RemovedExecution> remove(DayExecution execution) async {
    removed.add(execution.id);
    _hidden.add(execution.id);
    return RemovedExecution(
      id: execution.id,
      restoreToken: 'token-${execution.id}',
      restoreExpiresAt: DateTime.now().add(const Duration(seconds: 5)),
    );
  }

  @override
  Future<void> restore(RemovedExecution removed) async {
    restored.add(removed.restoreToken);
    _hidden.remove(removed.id);
  }
}
