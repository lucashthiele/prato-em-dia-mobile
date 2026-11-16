import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/app/theme/app_theme.dart';
import 'package:prato_em_dia_mobile/features/consent/domain/consent.dart';
import 'package:prato_em_dia_mobile/features/consent/presentation/consent_texts.dart';
import 'package:prato_em_dia_mobile/features/consent/presentation/cubit/consent_cubit.dart';
import 'package:prato_em_dia_mobile/features/consent/presentation/pages/consent_page.dart';

void main() {
  testWidgets(
    'shows both documents with the nutritionist visibility sentence',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(_FakeConsentRepository()));

      expect(find.text('Termos de uso'), findsOneWidget);
      expect(find.text('Política de privacidade'), findsOneWidget);
      expect(
        find.text(
          'O nutricionista vinculado a você vê as refeições que você planeja e registra no app.',
        ),
        findsOneWidget,
      );
      expect(
        ConsentTexts.termsParagraphs,
        contains(ConsentTexts.nutritionistVisibility),
      );
      expect(find.widgetWithText(FilledButton, 'Aceitar'), findsOneWidget);
    },
  );

  testWidgets('Aceitar records the consent and continues the flow', (
    tester,
  ) async {
    final repository = _FakeConsentRepository();
    var accepted = false;
    await tester.pumpWidget(
      _app(repository, onAccepted: () => accepted = true),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 1);
    expect(accepted, isTrue);
  });

  testWidgets('shows the failure and lets the patient try again', (
    tester,
  ) async {
    final repository = _FakeConsentRepository()..fail = true;
    var accepted = false;
    await tester.pumpWidget(
      _app(repository, onAccepted: () => accepted = true),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão.'), findsOneWidget);
    expect(accepted, isFalse);

    repository.fail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });

  testWidgets('fits a small phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_FakeConsentRepository()));

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, 'Aceitar'), findsOneWidget);
  });
}

Widget _app(ConsentRepository repository, {VoidCallback? onAccepted}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider(
        create: (_) => ConsentCubit(repository),
        child: ConsentPage(onAccepted: onAccepted ?? () {}),
      ),
    );

class _FakeConsentRepository implements ConsentRepository {
  int acceptCalls = 0;
  bool fail = false;

  static const _status = ConsentStatus(upToDate: true, documents: []);

  @override
  Future<ConsentStatus> status() async => _status;

  @override
  Future<ConsentStatus> acceptCurrent() async {
    acceptCalls++;
    if (fail) throw const ConsentFailure('Sem conexão.');
    return _status;
  }
}
