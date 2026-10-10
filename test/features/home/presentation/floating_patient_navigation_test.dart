import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/home/presentation/pages/patient_shell.dart';

void main() {
  testWidgets('five navigation actions fit a narrow phone in order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    int? selected;
    String? comingSoon;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: FloatingPatientNavigation(
                  selectedIndex: 0,
                  onSelected: (index) => selected = index,
                  onComingSoon: (message) => comingSoon = message,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FloatingPatientNavigation)).width, 288);
    expect(tester.getSize(find.byType(FloatingPatientNavigation)).height, 72);

    final destinations = [
      'Hoje',
      'Semana',
      'Adicionar (em breve)',
      'Compras',
      'Perfil',
    ];
    final positions = destinations
        .map((label) => tester.getCenter(find.byTooltip(label)).dx)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));

    await tester.tap(find.byTooltip('Hoje'));
    expect(selected, 0);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.text('Em breve'), findsNothing);
    await tester.tap(find.byTooltip('Semana'));
    expect(selected, 1);
    await tester.tap(find.byTooltip('Adicionar (em breve)'));
    expect(comingSoon, contains('em breve'));
    await tester.tap(find.byTooltip('Compras'));
    expect(comingSoon, contains('Compras'));
    await tester.tap(find.byTooltip('Perfil'));
    expect(selected, 2);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 700);
    await tester.pump();
    expect(tester.getSize(find.byType(FloatingPatientNavigation)).width, 358);
  });
}
