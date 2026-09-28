// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/domain/ports/active_sync_provider_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_credentials_port.dart';
import 'package:lockspire/features/sync/presentation/providers/active_sync_provider_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/is_sync_configured_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/sync_credentials_port_provider.dart';
import 'package:lockspire/features/sync/presentation/sync_controller.dart';

class _FakeSyncCredentialsPort implements SyncCredentialsPort {
  WebDavCredentials? _stored;

  @override
  Future<WebDavCredentials?> read() async => _stored;

  @override
  Future<void> save(WebDavCredentials credentials) async {
    _stored = credentials;
  }

  @override
  Future<void> clear() async => _stored = null;
}

class _FakeActiveSyncProviderPort implements ActiveSyncProviderPort {
  SyncProviderId? _active;

  @override
  Future<SyncProviderId?> activeProvider() async => _active;

  @override
  Future<void> saveActiveProvider(SyncProviderId id) async => _active = id;

  @override
  Future<void> clearActiveProvider() async => _active = null;
}

void main() {
  group(
    'SyncController.saveCredentials — invalidación de providers dependientes',
    () {
      test('isSyncConfiguredProvider pasa a true después de guardar '
          'credenciales, sin que el llamador tenga que invalidarlo a mano '
          '(regresión: quedaba en false porque solo se invalidaban los '
          'providers de las credenciales/proveedor activo, no este)', () async {
        final credentialsPort = _FakeSyncCredentialsPort();
        final activeProviderPort = _FakeActiveSyncProviderPort();
        final container = ProviderContainer(
          overrides: [
            syncCredentialsPortProvider.overrideWithValue(credentialsPort),
            activeSyncProviderPortProvider.overrideWithValue(
              activeProviderPort,
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(await container.read(isSyncConfiguredProvider.future), isFalse);

        await container
            .read(syncControllerProvider.notifier)
            .saveCredentials(
              const WebDavCredentials(
                serverUrl: 'https://example.test',
                username: 'u',
                password: 'p',
              ),
            );

        expect(await container.read(isSyncConfiguredProvider.future), isTrue);
      });
    },
  );
}
