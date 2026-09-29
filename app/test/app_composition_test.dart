// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/app_composition.dart';
import 'package:lockspire/features/sync/application/sync_password_changed_elsewhere.dart';
import 'package:lockspire/features/vault/application/password_changed_elsewhere_port.dart';
import 'package:lockspire/features/vault/presentation/providers/password_changed_elsewhere_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/active_sync_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/sync_ancestor_storage_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/sync_state_port_provider.dart';
import 'package:lockspire/features/vault/application/local_only_master_password_change_replica.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/master_password_change_replica_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';

import 'features/sync/application/fakes.dart';
import 'features/vault/application/fakes.dart';

void main() {
  group('Composition root de la app (hallazgo A3)', () {
    test('cambiar la contraseña maestra usa la réplica de sync — sin esta '
        'conexión dejaría de sincronizar en silencio (ADR 0018)', () async {
      final container = ProviderContainer(
        overrides: [
          ...appOverrides(),
          vaultStoragePortProvider.overrideWith(
            (ref) async => FakeVaultStoragePort(),
          ),
          syncAncestorStoragePortProvider.overrideWith(
            (ref) async => FakeVaultStoragePort(),
          ),
          activeSyncPortProvider.overrideWith((ref) async => FakeSyncPort()),
          syncStatePortProvider.overrideWith((ref) => FakeSyncStatePort()),
          cryptoPortProvider.overrideWith((ref) async => FakeCryptoPort()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(masterPasswordChangeReplicaPortProvider.future),
        // La de sync (que arma la nube con token fresco en cada uso), no la
        // de vault que no replica nada.
        isNot(isA<LocalOnlyMasterPasswordChangeReplica>()),
      );
      // Sin esta, un cambio de contraseña en otro dispositivo no se pediría
      // al abrir la app (ADR 0024).
      expect(
        await container.read(passwordChangedElsewherePortProvider.future),
        isA<SyncPasswordChangedElsewhere>(),
      );
    });

    test('sin la conexión, vault por sí solo no replica nada', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(masterPasswordChangeReplicaPortProvider.future),
        isA<LocalOnlyMasterPasswordChangeReplica>(),
      );
      expect(
        await container.read(passwordChangedElsewherePortProvider.future),
        isA<NoPasswordChangedElsewhere>(),
      );
    });
  });
}
