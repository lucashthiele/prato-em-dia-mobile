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
    expect(find.text('Senha atual'), findsNothing);
    expect(find.text('Sair da conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile mode asks for the current password and sends it', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    AuthSession? changedSession;
    await tester.pumpWidget(
      _appWith(
        repository,
        mode: ChangePasswordMode.fromProfile,
        onPasswordChanged: (session) => changedSession = session,
      ),
    );

    expect(find.text('Alterar senha'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Senha atual'), findsOneWidget);
    expect(find.text('Sair da conta'), findsNothing);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'senha-antiga');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'minha-nova-senha',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'minha-nova-senha',
    );
    final submit = find.widgetWithText(FilledButton, 'Alterar senha');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.lastCurrentPassword, 'senha-antiga');
    expect(repository.lastNewPassword, 'minha-nova-senha');
    expect(changedSession, isNotNull);
  });

  testWidgets('profile mode does not submit without the current password', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      _appWith(repository, mode: ChangePasswordMode.fromProfile),
    );

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'minha-nova-senha',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'minha-nova-senha',
    );
    final submit = find.widgetWithText(FilledButton, 'Alterar senha');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Informe a senha atual.'), findsOneWidget);
    expect(repository.calls, 0);
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

    // Primeiro acesso: nenhuma senha temporária é enviada.
    expect(repository.lastCurrentPassword, isNull);
    expect(repository.lastNewPassword, 'minha-nova-senha');
    expect(changedSession?.passwordChangeRequired, isFalse);
  });
}

Widget _appWith(
  AuthRepository repository, {
  ValueChanged<AuthSession>? onPasswordChanged,
  ChangePasswordMode mode = ChangePasswordMode.firstAccess,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider(
      create: (_) => ChangePasswordCubit(repository, mode: mode),
      child: ChangePasswordPage(
        mode: mode,
        onPasswordChanged: onPasswordChanged ?? (_) {},
        onLogout: mode == ChangePasswordMode.firstAccess ? () async {} : null,
        onCancel: mode == ChangePasswordMode.fromProfile ? () {} : null,
      ),
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  String? lastCurrentPassword;
  String? lastNewPassword;
  int calls = 0;

  @override
  Future<AuthSession> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    calls++;
    return const AuthSession(expiresIn: 300, passwordChangeRequired: false);
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
