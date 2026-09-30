// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/autofill/domain/autofill_session.dart';
import 'package:lockspire/features/autofill/domain/ports/autofill_host_port.dart';
import 'package:lockspire/features/autofill/infrastructure/method_channel_autofill_host.dart';
import 'package:lockspire/features/autofill/infrastructure/method_channel_autofill_settings.dart';

import '../../../support/fake_method_channel.dart';

/// El contrato con `AutofillActivity` y los ajustes del sistema en Kotlin
/// (ADR 0011): qué se manda por cada canal y cómo se leen las respuestas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pedido de autocompletado', () {
    late FakeMethodChannel kotlin;
    const host = MethodChannelAutofillHost();

    setUp(() => kotlin = FakeMethodChannel('com.lockspire.lockspire/autofill'));

    test('rellenar: la app y el origen web, solo si es un dominio '
        'limpio', () async {
      kotlin.answer('getRequest', {
        'mode': 'get',
        'packageName': 'com.android.chrome',
        'webDomain': 'Banco.Ejemplo',
        'webScheme': 'https',
      });

      final request = await host.request();

      expect(request, isA<AutofillFillRequest>());
      expect(request.packageName, 'com.android.chrome');
      expect(request.origin, 'https://banco.ejemplo');
    });

    test('guardar: trae el usuario y la contraseña escritos', () async {
      kotlin.answer('getRequest', {
        'mode': 'create',
        'packageName': 'com.banco.app',
        'username': 'ana',
        'password': 'Secreta-1',
      });

      final request = await host.request() as AutofillSaveRequest;

      expect(request.origin, isNull);
      expect(request.username, 'ana');
      expect(request.password, 'Secreta-1');
    });

    test('sin pedido (la actividad se abrió sola) no se hace nada', () async {
      expect(await host.request(), isA<AutofillUnknownRequest>());

      kotlin.answer('getRequest', {'mode': 'otro'});
      expect(await host.request(), isA<AutofillUnknownRequest>());
    });

    test('la sesión lleva solo lo necesario para coincidir y '
        'rellenar', () async {
      await host.startSession(
        ttl: const Duration(minutes: 5),
        trustedBrowsers: {'com.android.chrome'},
        items: const [
          AutofillSessionItem(
            title: 'Banco',
            username: 'ana',
            password: 'Secreta-1',
            sites: [(host: 'banco.ejemplo', httpsOnly: true)],
            apps: ['com.banco.app'],
          ),
        ],
      );

      expect(kotlin.argumentsOf('startSession'), {
        'ttlMillis': 300000,
        'trustedBrowsers': ['com.android.chrome'],
        'items': [
          {
            'title': 'Banco',
            'username': 'ana',
            'password': 'Secreta-1',
            'hosts': ['banco.ejemplo'],
            'httpsOnly': [true],
            'apps': ['com.banco.app'],
          },
        ],
      });
    });

    test('rellenar, confirmar y cancelar llegan a la actividad', () async {
      await host.fill(username: 'ana', password: 'Secreta-1');
      await host.confirmSaved();
      await host.cancel();

      expect(kotlin.methods, ['submitGet', 'submitCreate', 'cancel']);
      expect(kotlin.argumentsOf('submitGet'), {
        'username': 'ana',
        'password': 'Secreta-1',
      });
    });
  });

  group('Ajustes de autocompletado del sistema', () {
    late FakeMethodChannel kotlin;
    const settings = MethodChannelAutofillSettings();

    setUp(() => kotlin = FakeMethodChannel('com.lockspire.lockspire/settings'));

    test('abre la pantalla del sistema', () async {
      expect(await settings.open(), isTrue);
      expect(kotlin.methods, ['openAutofillServiceSettings']);
    });

    test('si el sistema no la tiene, lo dice sin lanzar', () async {
      kotlin.fail('openAutofillServiceSettings');

      expect(await settings.open(), isFalse);
    });
  });
}
