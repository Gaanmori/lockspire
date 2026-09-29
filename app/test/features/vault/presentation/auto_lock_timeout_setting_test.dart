// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/auto_lock_timeout.dart';
import 'package:lockspire/features/vault/domain/ports/auto_lock_preferences_port.dart';
import 'package:lockspire/features/vault/presentation/providers/auto_lock_preferences_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/auto_lock_timeout_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/auto_lock_timeout_setting_provider.dart';

class _FakePort implements AutoLockPreferencesPort {
  AutoLockTimeout stored;

  _FakePort([this.stored = AutoLockTimeout.defaultValue]);

  @override
  Future<AutoLockTimeout> load() async => stored;

  @override
  Future<void> save(AutoLockTimeout timeout) async => stored = timeout;
}

ProviderContainer _container(_FakePort port) {
  final container = ProviderContainer(
    overrides: [autoLockPreferencesPortProvider.overrideWithValue(port)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('solo hay 3 opciones: 1, 5 y 15 minutos, con 5 por defecto', () {
    expect(AutoLockTimeout.values.map((t) => t.duration), const [
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 15),
    ]);
    expect(AutoLockTimeout.defaultValue.duration, const Duration(minutes: 5));
  });

  test('sin nada guardado, el temporizador usa 5 minutos (ADR 0008)', () async {
    final container = _container(_FakePort());
    await container.read(autoLockTimeoutSettingProvider.future);
    expect(container.read(autoLockTimeoutProvider), const Duration(minutes: 5));
  });

  test('carga el valor guardado', () async {
    final container = _container(_FakePort(AutoLockTimeout.oneMinute));
    await container.read(autoLockTimeoutSettingProvider.future);
    expect(container.read(autoLockTimeoutProvider), const Duration(minutes: 1));
  });

  test('cambiarlo se aplica al temporizador y se guarda', () async {
    final port = _FakePort();
    final container = _container(port);
    await container.read(autoLockTimeoutSettingProvider.future);

    await container
        .read(autoLockTimeoutSettingProvider.notifier)
        .set(AutoLockTimeout.fifteenMinutes);

    expect(
      container.read(autoLockTimeoutProvider),
      const Duration(minutes: 15),
    );
    expect(port.stored, AutoLockTimeout.fifteenMinutes);
  });
}
