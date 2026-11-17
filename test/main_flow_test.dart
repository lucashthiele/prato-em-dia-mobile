import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/core/app_outdated/app_outdated_page.dart';
import 'package:prato_em_dia_mobile/features/auth/presentation/pages/change_password_page.dart';
import 'package:prato_em_dia_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:prato_em_dia_mobile/features/consent/presentation/pages/consent_page.dart';
import 'package:prato_em_dia_mobile/main.dart';

import 'core/network/fake_adapter.dart';

void main() {
  testWidgets('426 CLIENT_OUTDATED blocks the app with the update screen', (
    tester,
  ) async {
    final adapter = FakeAdapter((_) => errorEnvelope(426, 'CLIENT_OUTDATED'));
    await tester.pumpWidget(MainApp(apiClient: testClient(adapter)));
    await tester.pumpAndSettle();

    expect(find.byType(AppOutdatedPage), findsOneWidget);
  });

  testWidgets('no session on open goes to the login', (tester) async {
    final adapter = FakeAdapter(
      (_) => errorEnvelope(401, 'AUTHENTICATION_REQUIRED'),
    );
    await tester.pumpWidget(MainApp(apiClient: testClient(adapter)));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(adapter.count('/api/v1/auth/refresh'), 1);
  });

  testWidgets('restricted first-access session goes to the new password', (
    tester,
  ) async {
    final adapter = FakeAdapter(
      (_) => errorEnvelope(403, 'PASSWORD_CHANGE_REQUIRED'),
    );
    await tester.pumpWidget(MainApp(apiClient: testClient(adapter)));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordPage), findsOneWidget);
    expect(find.text('Senha atual'), findsNothing);
  });

  testWidgets(
    '403 CONSENT_REQUIRED shows the consent and repeats the request',
    (tester) async {
      var accepted = false;
      final adapter = FakeAdapter((options) {
        if (options.path == '/api/v1/me/consents') {
          if (options.method == 'POST') accepted = true;
          return json(200, {
            'upToDate': accepted,
            'documents': [
              {
                'documentType': 'TERMS_OF_USE',
                'currentVersion': 'placeholder-1',
                'accepted': accepted,
              },
              {
                'documentType': 'PRIVACY_POLICY',
                'currentVersion': 'placeholder-1',
                'accepted': accepted,
              },
            ],
          });
        }
        if (options.path == '/api/v1/me') {
          return accepted
              ? errorEnvelope(403, 'PASSWORD_CHANGE_REQUIRED')
              : errorEnvelope(403, 'CONSENT_REQUIRED');
        }
        return json(200, {});
      });
      await tester.pumpWidget(MainApp(apiClient: testClient(adapter)));
      // O indicador da abertura anima enquanto o aceite espera.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ConsentPage), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsentPage), findsNothing);
      expect(adapter.count('/api/v1/me'), 2);
      expect(
        adapter.requests.where(
          (r) => r.path == '/api/v1/me/consents' && r.method == 'POST',
        ),
        hasLength(2),
      );
      expect(find.byType(ChangePasswordPage), findsOneWidget);
    },
  );
}
