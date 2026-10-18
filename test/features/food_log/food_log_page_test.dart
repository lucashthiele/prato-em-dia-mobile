import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_session.dart';
import 'package:prato_em_dia_mobile/features/food_log/presentation/pages/food_log_page.dart';

const _session = AuthSession(
  accessToken: 'test-token',
  tokenType: 'Bearer',
  expiresIn: 3600,
  passwordChangeRequired: false,
);

void main() {
  testWidgets('reopening shows the consumption confirmed for the meal', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    List<dynamic>? savedItems;
    Map<String, dynamic>? savedBody;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          Object data;
          if (options.method == 'GET' && options.path.endsWith('/food-log')) {
            data = {
              'mode': 'FREE',
              'items': [
                {
                  'plannedItemId': 'planned-1',
                  'catalogFoodId': 'food-1',
                  'catalogPortionId': 'portion-1',
                  'quantity': 150,
                },
              ],
            };
          } else if (options.method == 'GET' &&
              options.path.endsWith('/meal-executions')) {
            data = savedItems == null
                ? <dynamic>[]
                : [
                    {
                      'id': 'exec-1',
                      'version': 1,
                      'plannedMealId': 'meal-1',
                      'items': savedItems,
                    },
                  ];
          } else if (options.method == 'GET' &&
              options.path.endsWith('/foods/food-1')) {
            data = {
              'id': 'food-1',
              'name': 'Aveia',
              'portions': [
                {
                  'id': 'portion-1',
                  'label': '100 g',
                  'quantity': 100,
                  'unit': 'g',
                  'nutrients': <String, dynamic>{},
                },
              ],
            };
          } else if (options.method == 'POST' &&
              options.path.endsWith('/meal-executions')) {
            savedBody = options.data as Map<String, dynamic>;
            savedItems =
                (options.data as Map<String, dynamic>)['items']
                    as List<dynamic>;
            data = {'id': 'exec-1'};
          } else {
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Unexpected request: ${options.method} ${options.path}',
              ),
            );
            return;
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: data),
          );
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FoodLogPage(
                      mealId: 'meal-1',
                      mealName: 'Café da manhã',
                      date: '2026-10-10',
                      mealType: 'BREAKFAST',
                      plannedTime: '07:30:00',
                      session: _session,
                      renewSession: () async => _session,
                      dio: dio,
                    ),
                  ),
                ),
                child: const Text('Abrir refeição'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir refeição'));
    await tester.pumpAndSettle();
    expect(find.text('1,5 × 100 g'), findsOneWidget);

    await tester.tap(find.text('Aveia'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Remover'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(find.text('Não consumido'), findsOneWidget);

    await tester.tap(find.text('Confirmar consumo'));
    await tester.pumpAndSettle();
    expect(savedBody!['time'], '07:30');
    expect(savedBody!['mealType'], 'BREAKFAST');
    expect(savedItems, isNotNull);
    expect(savedItems, isEmpty);

    await tester.tap(find.text('Abrir refeição'));
    await tester.pumpAndSettle();
    expect(find.text('Não consumido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Dio modeDio(String mode, List<dynamic> posted) {
    Map<String, dynamic> foodJson(String id, String name) => {
      'id': id,
      'name': name,
      'origin': 'TACO',
      'portions': [
        {
          'id': 'p-$id',
          'label': '100 g',
          'quantity': 100,
          'unit': 'g',
          'nutrients': {
            'energy_kcal': {'amount': 40, 'unit': 'kcal', 'status': 'VALUE'},
            'protein': {'amount': 2.5, 'unit': 'g', 'status': 'VALUE'},
            'lipids': {'status': 'TRACE', 'unit': 'g'},
          },
        },
      ],
    };
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          Object data;
          final path = options.path;
          if (path.endsWith('/food-log')) {
            data = {
              'mode': mode,
              'items': [
                {
                  'plannedItemId': 'planned-1',
                  'catalogFoodId': 'food-1',
                  'catalogPortionId': 'p-food-1',
                  'quantity': 100,
                  'allowedSubstitutions': [
                    {
                      'allowedSubstitutionId': 'allowed-1',
                      'catalogFoodId': 'food-2',
                      'catalogPortionId': 'p-food-2',
                      'quantity': 80,
                    },
                  ],
                },
              ],
            };
          } else if (options.method == 'GET' &&
              path.endsWith('/meal-executions')) {
            data = <dynamic>[];
          } else if (options.method == 'GET' && path.contains('/foods/')) {
            final id = path.split('/').last;
            data = foodJson(id, id == 'food-1' ? 'Aveia' : 'Banana');
          } else if (options.method == 'POST') {
            posted.addAll(
              (options.data as Map<String, dynamic>)['items'] as List<dynamic>,
            );
            data = {'id': 'event-1'};
          } else {
            handler.reject(
              DioException(requestOptions: options, error: 'Unexpected $path'),
            );
            return;
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: data),
          );
        },
      ),
    );
    return dio;
  }

  Future<void> open(WidgetTester tester, Dio dio) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FoodLogPage(
          mealId: 'meal-1',
          mealName: 'Almoço',
          date: '2026-10-10',
          mealType: 'LUNCH',
          plannedTime: '12:00:00',
          session: _session,
          renewSession: () async => _session,
          dio: dio,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('restricted mode only allows editing quantity', (tester) async {
    await open(tester, modeDio('RESTRICTED', []));
    await tester.tap(find.text('Aveia'));
    await tester.pumpAndSettle();
    expect(find.text('Trocar alimento'), findsNothing);
    expect(find.text('Remover'), findsNothing);
    expect(find.text('Adicionar alimento do catálogo'), findsNothing);
  });

  testWidgets('substitutions-only swaps via catalog listing allowed foods', (
    tester,
  ) async {
    final posted = <dynamic>[];
    await open(tester, modeDio('SUBSTITUTIONS_ONLY', posted));
    expect(find.text('Adicionar alimento do catálogo'), findsNothing);

    await tester.tap(find.text('Aveia'));
    await tester.pumpAndSettle();
    expect(find.text('40 kcal'), findsOneWidget);
    expect(find.text('2,5 g'), findsOneWidget);
    expect(find.text('não disponível'), findsWidgets);
    expect(find.text('Remover'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Trocar alimento'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Trocar alimento'));
    await tester.pumpAndSettle();

    expect(find.text('Escolher alimento'), findsOneWidget);
    expect(find.text('Aveia'), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Aplicar'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Banana'), findsOneWidget);

    await tester.tap(find.text('Confirmar consumo'));
    await tester.pumpAndSettle();
    final line = posted.single as Map<String, dynamic>;
    expect(line['foodId'], 'food-2');
    // One portion of 100 g: size as quantity, portion count as multiplier.
    expect(line['quantity'], 100);
    expect(line['multiplier'], 1);
    expect(line['allowedSubstitutionId'], 'allowed-1');
  });
}
