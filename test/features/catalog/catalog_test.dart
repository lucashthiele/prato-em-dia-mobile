import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:prato_em_dia_mobile/app/theme/app_theme.dart';
import 'package:prato_em_dia_mobile/features/catalog/data/catalog_api.dart';
import 'package:prato_em_dia_mobile/features/catalog/data/catalog_repository_impl.dart';
import 'package:prato_em_dia_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:prato_em_dia_mobile/features/catalog/presentation/cubit/catalog_cubit.dart';
import 'package:prato_em_dia_mobile/features/catalog/presentation/pages/catalog_screen.dart';
import 'package:prato_em_dia_mobile/features/catalog/presentation/pages/food_details_screen.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_session.dart';

void main() {
  test(
    'maps portions and preserves a nonnumeric nutrient as a nonnumeric value',
    () async {
      final api = _FakeApi();
      final details = await CatalogRepositoryImpl(api).get('food-1');

      expect(details.food.name, 'Aveia');
      expect(details.portions.single.gramsEquivalent, '30');
      expect(details.portions.single.nutrients['protein']?.amount, '4');
      expect(details.portions.single.nutrients['iron']?.amount, isNull);
      expect(details.portions.single.nutrients['iron']?.status, 'TRACE');
    },
  );

  test('deduplicates repeated IDs between pages', () async {
    final repository = _PagedRepository();
    final cubit = CatalogCubit(repository);
    await cubit.load();
    await cubit.loadMore();

    expect(cubit.state.foods.map((food) => food.id), ['one', 'two', 'three']);
    expect(cubit.state.hasMore, isFalse);
    await cubit.close();
  });

  test(
    'renews an expired session once and repeats the catalog request',
    () async {
      final authorizations = <String?>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              authorizations.add(options.headers['Authorization'] as String?);
              if (authorizations.length == 1) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response<void>(
                      requestOptions: options,
                      statusCode: 401,
                    ),
                  ),
                );
                return;
              }
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'content': <dynamic>[], 'totalPages': 0},
                ),
              );
            },
          ),
        );
      var renewals = 0;
      final api = CatalogApi(
        dio,
        const AuthSession(
          accessToken: 'old-token',
          tokenType: 'Bearer',
          expiresIn: 3600,
          passwordChangeRequired: false,
        ),
        () async {
          renewals++;
          return const AuthSession(
            accessToken: 'new-token',
            tokenType: 'Bearer',
            expiresIn: 3600,
            passwordChangeRequired: false,
          );
        },
      );

      await api.list(0);

      expect(renewals, 1);
      expect(authorizations, ['Bearer old-token', 'Bearer new-token']);
    },
  );

  testWidgets('shows an empty catalog with a retry action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CatalogScreen(repository: _EmptyRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum alimento disponível no catálogo.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('shows portion nutrients and uses a textual trace state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FoodDetailsScreen(
          food: _food('food-1', 'Aveia'),
          repository: _DetailsRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Proteínas'), findsOneWidget);
    expect(find.text('4 g'), findsOneWidget);
    expect(find.text('iron'), findsOneWidget);
    expect(find.text('traço'), findsOneWidget);
    expect(find.text('Equivalente: 30 g'), findsOneWidget);
  });

  testWidgets('search field keeps focus while results reload', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CatalogScreen(repository: _SearchRepository())),
    );
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byType(TextField), 'b');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'ba');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.hasAnyClients, isTrue);
  });

  testWidgets('searches the catalog on the server and shows empty results', (
    tester,
  ) async {
    final repository = _SearchRepository();
    await tester.pumpWidget(
      MaterialApp(home: CatalogScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aveia'), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ban');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.queries, ['', 'ban']);
    expect(find.text('Aveia'), findsNothing);
    expect(find.text('Banana'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum alimento encontrado para “xyz”.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(find.text('Aveia'), findsOneWidget);
  });
}

class _SearchRepository implements CatalogRepository {
  final queries = <String?>[];

  @override
  Future<FoodDetails> get(String id) => throw UnimplementedError();

  @override
  Future<CatalogPage> list(int page, {String? query}) async {
    queries.add(query);
    final all = [_food('1', 'Aveia'), _food('2', 'Banana')];
    final q = query ?? '';
    return CatalogPage(
      foods: [
        for (final f in all)
          if (f.name.toLowerCase().contains(q.toLowerCase())) f,
      ],
      totalPages: 1,
    );
  }
}

class _FakeApi implements CatalogRemoteDataSource {
  @override
  Future<Map<String, dynamic>> get(String id) async => {
    ..._foodJson('food-1', 'Aveia'),
    'notes': 'Sem açúcar adicionado',
    'portions': [
      {
        'id': 'portion-1',
        'label': '2 colheres',
        'quantity': 2,
        'unit': 'colheres',
        'gramsEquivalent': 30,
        'nutrients': {
          'protein': {'amount': 4, 'unit': 'g', 'status': 'VALUE'},
          'iron': {'amount': null, 'unit': 'mg', 'status': 'TRACE'},
        },
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> list(int page, {String? query}) async => {
    'content': [_foodJson('food-1', 'Aveia')],
    'totalPages': 1,
  };
}

class _PagedRepository implements CatalogRepository {
  @override
  Future<FoodDetails> get(String id) => throw UnimplementedError();

  @override
  Future<CatalogPage> list(int page, {String? query}) async => switch (page) {
    0 => CatalogPage(
      foods: [_food('one', 'A'), _food('two', 'B')],
      totalPages: 2,
    ),
    _ => CatalogPage(
      foods: [_food('two', 'B'), _food('three', 'C')],
      totalPages: 2,
    ),
  };
}

class _EmptyRepository implements CatalogRepository {
  @override
  Future<FoodDetails> get(String id) => throw UnimplementedError();

  @override
  Future<CatalogPage> list(int page, {String? query}) async =>
      const CatalogPage(foods: [], totalPages: 0);
}

class _DetailsRepository implements CatalogRepository {
  @override
  Future<FoodDetails> get(String id) async => FoodDetails(
    food: _food(id, 'Aveia'),
    portions: const [
      FoodPortion(
        id: 'portion-1',
        label: '2 colheres',
        quantity: '2',
        unit: 'colheres',
        gramsEquivalent: '30',
        nutrients: {
          'protein': Nutrient(status: 'VALUE', unit: 'g', amount: '4'),
          'iron': Nutrient(status: 'TRACE', unit: 'mg', rawValue: 'tr'),
        },
      ),
    ],
  );

  @override
  Future<CatalogPage> list(int page, {String? query}) =>
      throw UnimplementedError();
}

FoodSummary _food(String id, String name) => FoodSummary(
  id: id,
  name: name,
  origin: 'IMPORTED',
  source: 'TBCA',
  category: 'Cereais',
);

Map<String, dynamic> _foodJson(String id, String name) => {
  'id': id,
  'name': name,
  'origin': 'IMPORTED',
  'source': 'TBCA',
  'category': 'Cereais',
};
