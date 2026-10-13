import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/home/presentation/pages/patient_shell.dart';

void main() {
  testWidgets('shows only the three available patient destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FloatingPatientNavigation(
            selectedIndex: 0,
            onSelected: (index) => selected = index,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final navigation = find.byType(FloatingPatientNavigation);
    expect(tester.getSize(navigation).height, lessThan(120));
    expect(tester.getBottomLeft(navigation).dy, 700);
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Plano'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Compras'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    expect(selected, 1);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });
}
