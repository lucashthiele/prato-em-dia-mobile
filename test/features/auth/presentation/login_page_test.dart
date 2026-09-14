import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/app/theme/app_theme.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_repository.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_session.dart';
import 'package:prato_em_dia_mobile/features/auth/presentation/cubit/login_cubit.dart';
import 'package:prato_em_dia_mobile/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('validates required login fields', (tester) async {
    await tester.pumpWidget(_appWith(_FakeAuthRepository()));

    final submitButton = find.widgetWithText(FilledButton, 'Entrar');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text('Informe o seu e-mail.'), findsOneWidget);
    expect(find.text('Informe a sua senha.'), findsOneWidget);
  });

  testWidgets('submits the backend contract and returns the session', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    AuthSession? authenticatedSession;
    String? authenticatedPassword;
    await tester.pumpWidget(
      _appWith(
        repository,
        onAuthenticated: (session, currentPassword) {
          authenticatedSession = session;
          authenticatedPassword = currentPassword;
        },
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'paciente@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'senha-inicial');
    final submitButton = find.widgetWithText(FilledButton, 'Entrar');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(repository.lastEmail, 'paciente@example.com');
    expect(repository.lastPassword, 'senha-inicial');
    expect(authenticatedSession?.passwordChangeRequired, isTrue);
    expect(authenticatedPassword, 'senha-inicial');
  });
}

Widget _appWith(
  AuthRepository repository, {
  LoginAuthenticatedCallback? onAuthenticated,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider(
      create: (_) => LoginCubit(repository),
      child: LoginPage(onAuthenticated: onAuthenticated ?? (_, _) {}),
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  String? lastEmail;
  String? lastPassword;

  @override
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => throw UnimplementedError();

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    return const AuthSession(
      accessToken: 'access-token',
      tokenType: 'Bearer',
      expiresIn: 300,
      passwordChangeRequired: true,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession?> restoreSession() async => null;
}
