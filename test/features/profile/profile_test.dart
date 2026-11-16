import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_repository.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_session.dart';
import 'package:prato_em_dia_mobile/features/auth/presentation/pages/change_password_page.dart';
import 'package:prato_em_dia_mobile/features/prescription/data/current_prescription_mapper.dart';
import 'package:prato_em_dia_mobile/features/prescription/domain/current_prescription.dart';
import 'package:prato_em_dia_mobile/features/prescription/domain/current_prescription_repository.dart';
import 'package:prato_em_dia_mobile/features/prescription/presentation/pages/prescription_page.dart';
import 'package:prato_em_dia_mobile/features/prescription/presentation/widgets/no_prescription_empty_state.dart';
import 'package:prato_em_dia_mobile/features/profile/data/profile_api.dart';
import 'package:prato_em_dia_mobile/features/profile/domain/patient_profile.dart';
import 'package:prato_em_dia_mobile/features/profile/domain/profile_repository.dart';
import 'package:prato_em_dia_mobile/features/profile/presentation/pages/profile_page.dart';

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
            expect(options.headers.containsKey('Authorization'), isFalse);
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

      final result = await ProfileApi(dio).updateProfile(
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
    expect(await ProfileApi(dio).getRelationship(), isNull);
  });

  testWidgets('shows profile, empty relationship and editable patient fields', (
    tester,
  ) async {
    final repository = _FakeProfileRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          onLogout: () async {},
          repository: repository,
          prescriptionRepository: _FakePrescriptions(null),
          authRepository: _FakeAuth(),
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

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host({
    CurrentPrescriptionRepository? prescriptions,
    _FakeAuth? auth,
    ProfileRepository? profile,
  }) => MaterialApp(
    home: ProfilePage(
      onLogout: () async {},
      repository: profile ?? _FakeProfileRepository(),
      prescriptionRepository: prescriptions ?? _FakePrescriptions(null),
      authRepository: auth ?? _FakeAuth(),
    ),
  );

  testWidgets('cartão de prescrição abre a prescrição vigente', (tester) async {
    tall(tester);
    final prescription = currentPrescriptionFromJson({
      'id': 'v1',
      'number': 3,
      'status': 'PUBLISHED',
      'title': 'Plano de cutting',
      'notes': null,
      'createdByUserId': 'u1',
      'createdAt': '2026-11-01T10:00:00Z',
      'publishedAt': '2026-11-02T10:00:00Z',
      'meals': [],
      'nutritionTargets': [],
    });
    await tester.pumpWidget(
      host(prescriptions: _FakePrescriptions(prescription)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Plano de cutting · Versão 3'), findsOneWidget);
    await tester.ensureVisible(find.text('Minha prescrição'));
    await tester.tap(find.text('Minha prescrição'));
    await tester.pumpAndSettle();
    expect(find.byType(PrescriptionPage), findsOneWidget);
    expect(find.text('Versão 3'), findsOneWidget);
  });

  testWidgets('sem prescrição o cartão mostra o estado vazio', (tester) async {
    tall(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text(NoPrescriptionEmptyState.message), findsOneWidget);
    await tester.ensureVisible(find.text('Minha prescrição'));
    await tester.tap(find.text('Minha prescrição'));
    await tester.pumpAndSettle();
    expect(find.byType(NoPrescriptionEmptyState), findsOneWidget);
  });

  testWidgets('vínculo é só exibição, sem ação de encerrar', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      host(profile: _FakeProfileRepository(nutritionist: 'Dra. Bia')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dra. Bia'), findsOneWidget);
    expect(find.textContaining('Encerrar'), findsNothing);
    expect(find.textContaining('encerrar'), findsNothing);
  });

  testWidgets('trocar senha abre a página no modo Perfil e segue logado', (
    tester,
  ) async {
    tall(tester);
    final auth = _FakeAuth();
    await tester.pumpWidget(host(auth: auth));
    await tester.pumpAndSettle();
    expect(
      find.text('Ao trocar, os outros aparelhos serão desconectados.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Trocar senha'));
    await tester.tap(find.text('Trocar senha'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    expect(find.text('Senha atual'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha atual'),
      'senha-antiga-123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nova senha'),
      'senha-nova-12345',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirme a nova senha'),
      'senha-nova-12345',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Alterar senha'));
    await tester.pumpAndSettle();

    expect(auth.currentPassword, 'senha-antiga-123');
    expect(auth.newPassword, 'senha-nova-12345');
    expect(find.byType(ChangePasswordPage), findsNothing);
    expect(find.text('Meu perfil'), findsOneWidget);
    expect(
      find.text('Senha alterada. Os outros aparelhos foram desconectados.'),
      findsOneWidget,
    );
  });

  testWidgets('senha atual errada mostra a mensagem do código', (tester) async {
    tall(tester);
    await tester.pumpWidget(host(auth: _FakeAuth(fail: true)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Trocar senha'));
    await tester.tap(find.text('Trocar senha'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha atual'),
      'errada-errada-1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nova senha'),
      'senha-nova-12345',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirme a nova senha'),
      'senha-nova-12345',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Alterar senha'));
    await tester.pumpAndSettle();
    expect(find.text('A senha atual não confere.'), findsOneWidget);
    expect(find.byType(ChangePasswordPage), findsOneWidget);
  });

  test('erro do perfil usa o mapeador por código', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 404,
              data: {'status': 404, 'code': 'PROFILE_NOT_FOUND'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      ),
    );
    expect(
      ProfileApi(dio).getProfile(),
      throwsA(
        isA<ProfileFailure>().having(
          (e) => e.message,
          'message',
          'Seu perfil não foi encontrado.',
        ),
      ),
    );
  });

  testWidgets('failed profile load offers retry', (tester) async {
    final repository = _FakeProfileRepository(failOnce: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          onLogout: () async {},
          repository: repository,
          prescriptionRepository: _FakePrescriptions(null),
          authRepository: _FakeAuth(),
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
  _FakeProfileRepository({this.failOnce = false, this.nutritionist});

  final String? nutritionist;

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
  Future<PatientRelationship?> getRelationship() async => nutritionist == null
      ? null
      : PatientRelationship(nutritionistFullName: nutritionist!);

  @override
  Future<PatientProfile> updateProfile(PatientProfile profile) async {
    saved = profile;
    return profile;
  }
}

class _FakePrescriptions implements CurrentPrescriptionRepository {
  _FakePrescriptions(this.value);
  final CurrentPrescription? value;

  @override
  Future<CurrentPrescription?> fetchCurrent() async => value;

  @override
  Future<String?> suggestedTimeFor(String mealType) async => null;
}

class _FakeAuth implements AuthRepository {
  _FakeAuth({this.fail = false});
  final bool fail;
  String? currentPassword;
  String? newPassword;

  @override
  Future<AuthSession> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    if (fail) {
      throw const AuthFailure(
        'A senha atual não confere.',
        code: 'AUTH_INVALID_CREDENTIALS',
      );
    }
    this.currentPassword = currentPassword;
    this.newPassword = newPassword;
    return const AuthSession(passwordChangeRequired: false);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();
}
