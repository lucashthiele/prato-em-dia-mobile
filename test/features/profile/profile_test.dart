import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_session.dart';
import 'package:prato_em_dia_mobile/features/profile/data/profile_api.dart';
import 'package:prato_em_dia_mobile/features/profile/domain/patient_profile.dart';
import 'package:prato_em_dia_mobile/features/profile/domain/profile_repository.dart';
import 'package:prato_em_dia_mobile/features/profile/presentation/pages/profile_page.dart';

const _session = AuthSession(
  accessToken: 'access',
  tokenType: 'Bearer',
  expiresIn: 900,
  passwordChangeRequired: false,
);

void main() {
  test(
    'PUT sends only patient fields and required null professional fields',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      Map<String, dynamic>? sent;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent = Map<String, dynamic>.from(options.data as Map);
            expect(options.path, '/api/v1/me');
            expect(options.headers['Authorization'], 'Bearer access');
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'fullName': 'Ana Lima',
                  'phone': null,
                  'birthDate': '1990-02-03',
                },
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final result = await ProfileApi(dio, _session).updateProfile(
        const PatientProfile(fullName: ' Ana Lima ', birthDate: '1990-02-03'),
      );

      expect(result.fullName, 'Ana Lima');
      expect(sent, {
        'fullName': 'Ana Lima',
        'phone': null,
        'registrationNumber': null,
        'bio': null,
        'birthDate': '1990-02-03',
      });
    },
  );

  test('relationship 404 is treated as no active link', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 404),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );
    expect(await ProfileApi(dio, _session).getRelationship(), isNull);
  });

  test('401 renews the session and retries once with the new token', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final tokens = <String?>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          tokens.add(options.headers['Authorization'] as String?);
          if (tokens.length == 1) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: 401),
                type: DioExceptionType.badResponse,
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'fullName': 'Ana Lima',
                  'phone': null,
                  'birthDate': null,
                },
                statusCode: 200,
              ),
            );
          }
        },
      ),
    );
    final api = ProfileApi(
      dio,
      _session,
      refreshSession: () async => const AuthSession(
        accessToken: 'renewed',
        tokenType: 'Bearer',
        expiresIn: 900,
        passwordChangeRequired: false,
      ),
    );

    expect((await api.getProfile()).fullName, 'Ana Lima');
    expect(tokens, ['Bearer access', 'Bearer renewed']);
  });

  testWidgets('shows profile, empty relationship and editable patient fields', (
    tester,
  ) async {
    final repository = _FakeProfileRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          session: _session,
          onLogout: () async {},
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Lima'), findsWidgets);
    expect(find.text('Nenhum vínculo ativo no momento.'), findsOneWidget);
    await tester.tap(find.text('Editar dados'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Nome completo'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Telefone (opcional)'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome completo'),
      'Ana Maria Lima',
    );
    await tester.ensureVisible(find.text('Salvar dados'));
    await tester.tap(find.text('Salvar dados'));
    await tester.pumpAndSettle();

    expect(repository.saved?.fullName, 'Ana Maria Lima');
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('Dados salvos.'), findsOneWidget);
  });

  testWidgets('failed profile load offers retry', (tester) async {
    final repository = _FakeProfileRepository(failOnce: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          session: _session,
          onLogout: () async {},
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Editar dados'), findsOneWidget);
  });
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.failOnce = false});

  bool failOnce;
  PatientProfile? saved;

  @override
  Future<PatientProfile> getProfile() async {
    if (failOnce) {
      failOnce = false;
      throw const ProfileFailure('Falha ao carregar.');
    }
    return saved ?? const PatientProfile(fullName: 'Ana Lima');
  }

  @override
  Future<PatientRelationship?> getRelationship() async => null;

  @override
  Future<PatientProfile> updateProfile(PatientProfile profile) async {
    saved = profile;
    return profile;
  }
}
