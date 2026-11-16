import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/app/theme/app_theme.dart';
import 'package:prato_em_dia_mobile/core/app_outdated/app_outdated_page.dart';

void main() {
  testWidgets('blocks with only the update message and no link or action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AppOutdatedPage()),
    );

    expect(find.text('Atualize o aplicativo'), findsOneWidget);
    expect(find.text(AppOutdatedPage.message), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });
}
