import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/app/theme/app_theme.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_repository.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_session.dart';
import 'package:prato_em_dia_mobile/features/auth/presentation/cubit/change_password_cubit.dart';
import 'package:prato_em_dia_mobile/features/auth/presentation/pages/change_password_page.dart';

void main() {
  testWidgets('keeps the form usable on a small phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_appWith(_FakeAuthRepository()));

    expect(find.text('Crie sua senha pessoal'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Senha inicial'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates the password rules and confirmation', (tester) async {
    await tester.pumpWidget(_appWith(_FakeAuthRepository()));

    await tester.enterText(find.byType(TextFormField).at(0), 'curta');
    await tester.enterText(find.byType(TextFormField).at(1), 'diferente');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Salvar e continuar'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar e continuar'));
    await tester.pump();

    expect(find.text('Use entre 12 e 72 caracteres.'), findsWidgets);
    expect(find.text('As senhas não coincidem.'), findsOneWidget);
  });

  testWidgets('changes the password and returns the renewed session', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    AuthSession? changedSession;
    await tester.pumpWidget(
      _appWith(
        repository,
        onPasswordChanged: (session) => changedSession = session,
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'minha-nova-senha',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'minha-nova-senha',
    );
    final submitButton = find.widgetWithText(
      FilledButton,
      'Salvar e continuar',
    );
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(repository.lastCurrentPassword, 'senha-inicial');
    expect(repository.lastNewPassword, 'minha-nova-senha');
    expect(changedSession?.passwordChangeRequired, isFalse);
  });
}

Widget _appWith(
  AuthRepository repository, {
  ValueChanged<AuthSession>? onPasswordChanged,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider(
      create: (_) => ChangePasswordCubit(repository, 'senha-inicial'),
      child: ChangePasswordPage(
        onPasswordChanged: onPasswordChanged ?? (_) {},
        onLogout: () async {},
      ),
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  String? lastCurrentPassword;
  String? lastNewPassword;

  @override
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    return const AuthSession(
      accessToken: 'new-access-token',
      tokenType: 'Bearer',
      expiresIn: 300,
      passwordChangeRequired: false,
    );
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession?> restoreSession() async => null;
}
