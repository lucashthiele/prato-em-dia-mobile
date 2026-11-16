import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/prescription/data/current_prescription_api.dart';
import 'package:prato_em_dia_mobile/features/prescription/data/current_prescription_mapper.dart';
import 'package:prato_em_dia_mobile/features/prescription/domain/current_prescription.dart';
import 'package:prato_em_dia_mobile/features/prescription/domain/current_prescription_repository.dart';
import 'package:prato_em_dia_mobile/features/prescription/presentation/pages/prescription_page.dart';
import 'package:prato_em_dia_mobile/features/prescription/presentation/widgets/no_prescription_empty_state.dart';

// Fiel ao PrescriptionOutput.VersionOutput (meals/itens fora de ordem).
Map<String, dynamic> fixture() => {
  'id': 'v1',
  'number': 3,
  'status': 'PUBLISHED',
  'title': 'Plano de cutting',
  'notes': 'Beber 2L de água.',
  'createdByUserId': 'u1',
  'createdAt': '2026-11-01T10:00:00Z',
  'publishedAt': '2026-11-02T10:00:00Z',
  'archivedAt': null,
  'meals': [
    {
      'id': 'm2',
      'name': 'Almoço',
      'mealType': 'LUNCH',
      'order': 2,
      'suggestedTime': '12:30:00',
      'notes': null,
      'items': [
        {
          'id': 'i1',
          'foodId': 'f-rice',
          'foodPortionId': 'p1',
          'quantity': 150.5,
          'unit': 'g',
          'order': 1,
          'notes': null,
          'substitutions': [
            {
              'id': 's1',
              'foodId': 'f-potato',
              'foodPortionId': null,
              'quantity': '200',
              'unit': 'g',
              'notes': null,
            },
          ],
        },
      ],
    },
    {
      'id': 'm1',
      'name': 'Café',
      'mealType': 'BREAKFAST',
      'order': 1,
      'suggestedTime': null,
      'notes': 'Sem açúcar',
      'items': [],
    },
  ],
  'nutritionTargets': [
    {'nutrientCode': 'energy_kcal', 'amount': 1800, 'unit': 'kcal'},
    {'nutrientCode': 'protein', 'amount': 120.5, 'unit': 'g'},
  ],
};

class FakeRepo implements CurrentPrescriptionRepository {
  FakeRepo(this.value);
  final CurrentPrescription? value;
  @override
  Future<CurrentPrescription?> fetchCurrent() async => value;
  @override
  Future<String?> suggestedTimeFor(String mealType) async =>
      value?.suggestedTimeFor(mealType);
}

Dio dioWith(int status, Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://x'));
  dio.httpClientAdapter = _Adapter(status, body);
  return dio;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final Object? body;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('mapeamento', () {
    test('lê o DTO do servidor', () {
      final p = currentPrescriptionFromJson(fixture());
      expect(p.number, 3);
      expect(p.title, 'Plano de cutting');
      expect(p.publishedAt, DateTime.utc(2026, 11, 2, 10));
      expect(p.createdByUserId, 'u1');
      expect(p.meals.map((m) => m.id), ['m1', 'm2']);
      final lunch = p.meals[1];
      expect(lunch.suggestedTime, '12:30');
      expect(lunch.items.single.quantity, '150.5');
      expect(lunch.items.single.substitutions.single.foodId, 'f-potato');
      expect(p.targets.energyKcal, '1800');
      expect(p.targets.protein, '120.5');
      expect(p.targets.carbohydrate, isNull);
      expect(p.planningMode, isNull);
      expect(p.suggestedTimeFor('LUNCH'), '12:30');
      expect(p.suggestedTimeFor('BREAKFAST'), isNull);
    });

    test('lê planningMode quando presente', () {
      final p = currentPrescriptionFromJson({
        ...fixture(),
        'planningMode': 'SUBSTITUTIONS_ONLY',
      });
      expect(p.planningMode, PlanningMode.substitutionsOnly);
      expect(p.planningMode!.label, 'Somente substituições');
    });

    test('campo obrigatório ausente lança FormatException', () {
      expect(
        () => currentPrescriptionFromJson({...fixture(), 'number': null}),
        throwsFormatException,
      );
    });
  });

  group('repositório', () {
    test('200 devolve a prescrição', () async {
      final repo = CurrentPrescriptionApi(dioWith(200, fixture()));
      final p = await repo.fetchCurrent();
      expect(p!.number, 3);
      expect(await repo.suggestedTimeFor('LUNCH'), '12:30');
    });

    test(
      '404 PRESCRIPTION_NOT_FOUND devolve null e sem Authorization',
      () async {
        final dio = dioWith(404, {
          'status': 404,
          'code': 'PRESCRIPTION_NOT_FOUND',
          'message': 'não encontrada',
          'errors': [],
        });
        final repo = CurrentPrescriptionApi(dio);
        expect(await repo.fetchCurrent(), isNull);
        final adapter = dio.httpClientAdapter as _Adapter;
        expect(adapter.last!.headers.containsKey('Authorization'), isFalse);
        expect(adapter.last!.path, '/api/v1/patients/me/prescriptions/current');
      },
    );

    test('outros erros propagam', () async {
      final repo = CurrentPrescriptionApi(
        dioWith(404, {'status': 404, 'code': 'OTHER', 'errors': []}),
      );
      expect(repo.fetchCurrent(), throwsA(isA<DioException>()));
      final repo500 = CurrentPrescriptionApi(
        dioWith(500, {'status': 500, 'code': 'INTERNAL', 'errors': []}),
      );
      expect(repo500.fetchCurrent(), throwsA(isA<DioException>()));
    });
  });

  group('página', () {
    Widget host(CurrentPrescriptionRepository repo) => MaterialApp(
      home: PrescriptionPage(
        repository: repo,
        nutritionistName: 'Dra. Ana',
        resolveFoodName: (id) async =>
            {'f-rice': 'Arroz', 'f-potato': 'Batata'}[id],
      ),
    );

    testWidgets('mostra a prescrição somente leitura', (tester) async {
      await tester.pumpWidget(
        host(FakeRepo(currentPrescriptionFromJson(fixture()))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Versão 3'), findsOneWidget);
      expect(find.text('Publicada em 02/11/2026'), findsOneWidget);
      expect(find.text('Nutricionista: Dra. Ana'), findsOneWidget);
      expect(find.text('Almoço · 12:30'), findsNothing); // categoria pt-BR
      expect(find.text('Almoço'), findsWidgets);
      expect(find.text('Arroz — 150,5 g'), findsOneWidget);
      expect(find.text('• Batata — 200 g'), findsOneWidget);
      expect(find.text('Energia: 1800 kcal'), findsOneWidget);
      expect(find.text('Beber 2L de água.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('mostra o estado vazio sem prescrição', (tester) async {
      await tester.pumpWidget(host(FakeRepo(null)));
      await tester.pumpAndSettle();
      expect(find.byType(NoPrescriptionEmptyState), findsOneWidget);
      expect(find.text(NoPrescriptionEmptyState.message), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
