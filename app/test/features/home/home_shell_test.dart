// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/home/presentation/home_destination.dart';
import 'package:lockspire/features/home/presentation/navigation_layout.dart';
import 'package:lockspire/features/home/presentation/screens/settings_screen.dart';
import 'package:lockspire/features/home/presentation/widgets/home_shell.dart';

/// Sección de prueba con estado propio (un contador) para comprobar que
/// cambiar de pestaña no lo pierde.
class _Counter extends StatefulWidget {
  final String name;
  const _Counter(this.name);

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => _count++),
      child: Text('${widget.name}: $_count'),
    ),
  );
}

List<HomeDestination> _destinations() => [
  HomeDestination(
    label: 'Uno',
    icon: Icons.looks_one_outlined,
    selectedIcon: Icons.looks_one,
    builder: (_, _) => const _Counter('uno'),
  ),
  HomeDestination(
    label: 'Dos',
    icon: Icons.looks_two_outlined,
    selectedIcon: Icons.looks_two,
    builder: (_, _) => const _Counter('dos'),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  VoidCallback? onLock,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: HomeShell(destinations: _destinations(), onLock: onLock ?? () {}),
    ),
  );
}

void main() {
  group('navigationLayoutFor (clases de ventana de M3)', () {
    test('compacta (< 600) → barra inferior; resto → riel', () {
      expect(navigationLayoutFor(360), NavigationLayout.bar);
      expect(navigationLayoutFor(599.9), NavigationLayout.bar);
      expect(navigationLayoutFor(600), NavigationLayout.rail);
      expect(navigationLayoutFor(1280), NavigationLayout.rail);
    });
  });

  testWidgets('en ventana compacta usa NavigationBar, sin riel', (
    tester,
  ) async {
    await _pump(tester, size: const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('en escritorio usa NavigationRail con Bloquear al pie', (
    tester,
  ) async {
    var locked = 0;
    await _pump(tester, size: const Size(1280, 800), onLock: () => locked++);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('Bloquear'));
    expect(locked, 1);
  });

  testWidgets('cada sección recibe la disposición activa (para no duplicar '
      'Bloquear, que en el riel ya está al pie)', (tester) async {
    final seen = <NavigationLayout>[];
    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(
            onLock: () {},
            destinations: [
              HomeDestination(
                label: 'Uno',
                icon: Icons.looks_one_outlined,
                selectedIcon: Icons.looks_one,
                builder: (_, layout) {
                  seen.add(layout);
                  return const SizedBox();
                },
              ),
              ..._destinations().skip(1),
            ],
          ),
        ),
      );
    }

    addTearDown(tester.view.reset);
    await pumpAt(const Size(400, 800));
    expect(seen.last, NavigationLayout.bar);
    await pumpAt(const Size(1280, 800));
    expect(seen.last, NavigationLayout.rail);
  });

  testWidgets('cambiar de sección conserva el estado de cada una', (
    tester,
  ) async {
    await _pump(tester, size: const Size(400, 800));

    await tester.tap(find.text('uno: 0'));
    await tester.pump();
    expect(find.text('uno: 1'), findsOneWidget);

    await tester.tap(find.text('Dos'));
    await tester.pumpAndSettle();
    expect(find.text('dos: 0'), findsOneWidget);

    await tester.tap(find.text('Uno'));
    await tester.pumpAndSettle();
    expect(find.text('uno: 1'), findsOneWidget);
  });

  testWidgets('Ajustes abre la pantalla de cada opción', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          items: [
            SettingsItem(
              icon: Icons.palette_outlined,
              title: 'Apariencia',
              subtitle: 'Tema',
              builder: (_) => const Scaffold(body: Text('pantalla apariencia')),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Apariencia'));
    await tester.pumpAndSettle();
    expect(find.text('pantalla apariencia'), findsOneWidget);
  });
}
