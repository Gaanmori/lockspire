// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/presentation/auto_lock_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';

import 'vault_session_harness.dart';

Future<ProviderContainer> _unlocked({Duration timeout = shortTimeout}) async {
  final container = buildSessionContainer(timeout: timeout).container;
  await container.read(vaultSessionControllerProvider.future);
  await container
      .read(vaultSessionControllerProvider.notifier)
      .createVault(masterPassword);
  return container;
}

void _background(ProviderContainer container) => container
    .read(autoLockControllerProvider)
    .onAppLifecycleChanged(AppLifecycleState.paused);

bool _isUnlocked(ProviderContainer container) =>
    container.read(vaultSessionControllerProvider).value
        is VaultSessionUnlocked;

/// Ventanas del sistema (selector de archivos, login de una nube, pago de
/// la tienda): en Android abren otra Activity y la app pasa a segundo
/// plano. Bloquear ahí perdía la respuesta: importar y exportar eran
/// imposibles (encontrado el 2026-09-30).
void main() {
  test('con una ventana del sistema abierta, pasar a segundo plano no '
      'bloquea; al cerrarse, vuelve a bloquear', () async {
    final container = await _unlocked(timeout: const Duration(minutes: 5));
    final picker = Completer<String>();

    final result = container
        .read(autoLockControllerProvider)
        .whileInSystemUi(() => picker.future);
    _background(container);
    expect(_isUnlocked(container), isTrue);

    picker.complete('archivo.csv');
    expect(await result, 'archivo.csv');

    _background(container);
    expect(_isUnlocked(container), isFalse);
  });

  test('si la ventana falla, la exención se levanta igual', () async {
    final container = await _unlocked(timeout: const Duration(minutes: 5));

    await expectLater(
      container
          .read(autoLockControllerProvider)
          .whileInSystemUi<void>(() async => throw StateError('sin permiso')),
      throwsStateError,
    );

    _background(container);
    expect(_isUnlocked(container), isFalse);
  });

  test(
    'con dos ventanas abiertas, cerrar una no levanta la exención',
    () async {
      final container = await _unlocked(timeout: const Duration(minutes: 5));
      final first = Completer<void>();
      final second = Completer<void>();
      final autoLock = container.read(autoLockControllerProvider);

      final a = autoLock.whileInSystemUi(() => first.future);
      final b = autoLock.whileInSystemUi(() => second.future);
      first.complete();
      await a;
      _background(container);
      expect(_isUnlocked(container), isTrue);

      second.complete();
      await b;
      _background(container);
      expect(_isUnlocked(container), isFalse);
    },
  );

  test('el bloqueo por inactividad sigue corriendo con la ventana abierta: '
      'una olvidada no deja la bóveda abierta', () {
    withFakeClock((clock, settle) {
      final container = buildSessionContainer().container;
      settle(container.read(vaultSessionControllerProvider.future));
      settle(
        container
            .read(vaultSessionControllerProvider.notifier)
            .createVault(masterPassword),
      );

      unawaited(
        container
            .read(autoLockControllerProvider)
            .whileInSystemUi(() => Completer<void>().future),
      );
      _background(container);
      expect(_isUnlocked(container), isTrue);

      clock.elapse(shortTimeout * 2);
      expect(_isUnlocked(container), isFalse);
    });
  });
}
