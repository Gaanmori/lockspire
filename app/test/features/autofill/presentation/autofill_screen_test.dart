// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/autofill/presentation/screens/autofill_screen.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/l10n/l10n.dart';

const _channel = MethodChannel('com.lockspire.lockspire/autofill');

VaultEntry _entry(String title, {String? url}) => VaultEntry(
  id: title,
  type: VaultEntryType.password,
  title: title,
  createdAt: DateTime.utc(2026, 1, 1),
  modifiedAt: DateTime.utc(2026, 1, 1),
  fields: {'username': 'yo', 'password': 'secreto', 'url': ?url},
);

/// Pide autofill [webDomain] dentro de [packageName] y registra qué se
/// rellena (ADR 0020).
Future<List<MethodCall>> _pumpGet(
  WidgetTester tester, {
  required List<VaultEntry> entries,
  String? webDomain,
  String packageName = 'com.android.chrome',
}) async {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
    call,
  ) async {
    calls.add(call);
    if (call.method == 'getRequest') {
      return {
        'mode': 'get',
        'packageName': packageName,
        'webDomain': webDomain,
        'webScheme': 'https',
      };
    }
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AutofillScreen(
          vault: Vault(vaultId: 'v', schemaVersion: 1, entries: entries),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

Iterable<MethodCall> _fills(List<MethodCall> calls) =>
    calls.where((c) => c.method == 'submitGet');

void main() {
  group('AutofillScreen con página web (S6, ADR 0020)', () {
    testWidgets('muestra el sitio y la app que lo pide', (tester) async {
      await _pumpGet(
        tester,
        entries: [_entry('Banco', url: 'banco.com')],
        webDomain: 'banco.com',
      );
      expect(find.text('banco.com'), findsOneWidget);
      expect(find.text('en Chrome'), findsOneWidget);
    });

    testWidgets('la entrada del mismo sitio se rellena sin preguntar', (
      tester,
    ) async {
      final calls = await _pumpGet(
        tester,
        entries: [_entry('Banco', url: 'banco.com')],
        webDomain: 'login.banco.com',
      );
      await tester.tap(find.text('Banco'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_fills(calls), hasLength(1));
    });

    testWidgets('en una página falsa advierte y, si se cancela, no rellena '
        'nada', (tester) async {
      final calls = await _pumpGet(
        tester,
        entries: [_entry('Banco', url: 'banco.com')],
        webDomain: 'banco-falso.com',
        packageName: 'com.app.sospechosa',
      );
      expect(find.text('dentro de la app com.app.sospechosa'), findsOneWidget);

      await tester.tap(find.text('Banco'));
      await tester.pumpAndSettle();
      expect(find.text('¿Es el sitio correcto?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(_fills(calls), isEmpty);
    });

    testWidgets('en una página de otro sitio, "Rellenar igual" rellena', (
      tester,
    ) async {
      final calls = await _pumpGet(
        tester,
        entries: [_entry('Banco', url: 'banco.com')],
        webDomain: 'otro.com',
      );
      await tester.tap(find.text('Banco'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rellenar igual'));
      await tester.pumpAndSettle();
      expect(_fills(calls), hasLength(1));
    });

    testWidgets('una entrada sin sitio pregunta; "Solo esta vez" rellena', (
      tester,
    ) async {
      final calls = await _pumpGet(
        tester,
        entries: [_entry('Banco')],
        webDomain: 'banco.com',
      );
      await tester.tap(find.text('Banco'));
      await tester.pumpAndSettle();
      expect(find.text('Esta entrada no tiene sitio'), findsOneWidget);

      await tester.tap(find.text('Solo esta vez'));
      await tester.pumpAndSettle();
      expect(_fills(calls), hasLength(1));
    });
  });

  testWidgets('sin página web (app nativa) se rellena directo, como antes', (
    tester,
  ) async {
    final calls = await _pumpGet(
      tester,
      entries: [_entry('Banco', url: 'banco.com')],
      packageName: 'com.banco.app',
    );
    expect(find.text('App de Android'), findsOneWidget);
    await tester.tap(find.text('Banco'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(_fills(calls), hasLength(1));
  });
}
