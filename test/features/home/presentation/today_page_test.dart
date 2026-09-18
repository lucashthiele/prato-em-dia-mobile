import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/app/theme/app_theme.dart';
import 'package:prato_em_dia_mobile/features/home/presentation/pages/today_page.dart';

void main() {
  testWidgets('confirms a planned meal and updates daily calories', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TodayPage(onLogout: () async {}),
      ),
    );

    expect(_calories(tester), '385 / 1.745 kcal');
    await tester.tap(find.text('Frango grelhado com arroz'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar como planejada'), findsOneWidget);
    await tester.tap(find.text('Confirmar como planejada'));
    await tester.pumpAndSettle();

    expect(_calories(tester), '1005 / 1.745 kcal');
    expect(find.text('76 g'), findsOneWidget);
    expect(find.text('Almoço confirmada para hoje.'), findsOneWidget);
  });
}

String _calories(WidgetTester tester) => tester
    .widget<RichText>(find.byKey(const Key('daily-calories')))
    .text
    .toPlainText();
