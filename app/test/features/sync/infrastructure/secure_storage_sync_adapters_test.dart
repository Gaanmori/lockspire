// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/domain/ports/active_sync_provider_port.dart';
import 'package:lockspire/features/sync/domain/ports/google_drive_account_port.dart';
import 'package:lockspire/features/sync/domain/ports/one_drive_account_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_credentials_port.dart';
import 'package:lockspire/features/sync/infrastructure/secure_storage_active_sync_provider_adapter.dart';
import 'package:lockspire/features/sync/infrastructure/secure_storage_google_drive_account_adapter.dart';
import 'package:lockspire/features/sync/infrastructure/secure_storage_one_drive_account_adapter.dart';
import 'package:lockspire/features/sync/infrastructure/secure_storage_sync_credentials_adapter.dart';

/// Cuentas y credenciales de las nubes en el almacenamiento seguro del
/// sistema (Keystore, DPAPI, libsecret), aquí simulado.
void main() {
  late Map<String, String> stored;
  const storage = FlutterSecureStorage();

  setUp(() {
    stored = {};
    FlutterSecureStorage.setMockInitialValues(stored);
  });

  group('Google Drive', () {
    const adapter = SecureStorageGoogleDriveAccountAdapter(storage);

    test('guarda y recupera la cuenta con su refresh token', () async {
      expect(await adapter.googleDriveAccount(), isNull);

      await adapter.saveGoogleDriveAccount(
        const GoogleDriveAccount(
          email: 'ana@gmail.ejemplo',
          refreshToken: 'r1',
        ),
      );

      final account = await adapter.googleDriveAccount();
      expect(account!.email, 'ana@gmail.ejemplo');
      expect(account.refreshToken, 'r1');
    });

    test('en Android no hay refresh token (lo maneja el sistema)', () async {
      await adapter.saveGoogleDriveAccount(
        const GoogleDriveAccount(email: 'ana@gmail.ejemplo'),
      );

      expect((await adapter.googleDriveAccount())!.refreshToken, isNull);
    });

    test('desconectar borra correo y token', () async {
      await adapter.saveGoogleDriveAccount(
        const GoogleDriveAccount(
          email: 'ana@gmail.ejemplo',
          refreshToken: 'r1',
        ),
      );

      await adapter.clearGoogleDriveAccount();

      expect(await adapter.googleDriveAccount(), isNull);
      expect(stored, isEmpty);
    });
  });

  group('OneDrive', () {
    const adapter = SecureStorageOneDriveAccountAdapter(storage);

    test('guarda y recupera la cuenta; sin token no hay cuenta', () async {
      await adapter.saveOneDriveAccount(
        const OneDriveAccount(email: 'ana@outlook.ejemplo', refreshToken: 'r1'),
      );
      expect((await adapter.oneDriveAccount())!.refreshToken, 'r1');

      stored.removeWhere((key, _) => key.contains('refresh'));
      expect(await adapter.oneDriveAccount(), isNull);
    });

    test('desconectar borra correo y token', () async {
      await adapter.saveOneDriveAccount(
        const OneDriveAccount(email: 'ana@outlook.ejemplo', refreshToken: 'r1'),
      );

      await adapter.clearOneDriveAccount();

      expect(stored, isEmpty);
    });
  });

  group('WebDAV', () {
    const adapter = SecureStorageSyncCredentialsAdapter(storage);
    const credentials = WebDavCredentials(
      serverUrl: 'https://nube.ejemplo/dav',
      username: 'ana',
      password: 'clave',
    );

    test('guarda y recupera las credenciales completas', () async {
      expect(await adapter.read(), isNull);

      await adapter.save(credentials);

      final back = await adapter.read();
      expect(back!.serverUrl, credentials.serverUrl);
      expect(back.username, credentials.username);
      expect(back.password, credentials.password);
    });

    test('credenciales a medias no cuentan', () async {
      await adapter.save(credentials);
      stored.removeWhere((key, _) => key.contains('password'));

      expect(await adapter.read(), isNull);
    });

    test('borrar también olvida la última sincronización', () async {
      await adapter.save(credentials);
      stored['sync.last_synced_hash'] = 'abc';

      await adapter.clear();

      expect(stored, isEmpty);
    });
  });

  group('Nube activa', () {
    const adapter = SecureStorageActiveSyncProviderAdapter(storage);

    test('guarda cada nube por su nombre y la olvida', () async {
      for (final id in SyncProviderId.values) {
        await adapter.saveActiveProvider(id);
        expect(await adapter.activeProvider(), id);
      }

      await adapter.clearActiveProvider();
      expect(await adapter.activeProvider(), isNull);
    });

    test('un valor desconocido (de otra versión) se ignora', () async {
      await adapter.saveActiveProvider(SyncProviderId.webdav);
      final key = stored.keys.single;
      stored[key] = 'dropbox';

      expect(await adapter.activeProvider(), isNull);
    });
  });
}
