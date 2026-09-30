// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/profiles/domain/profile.dart';
import 'package:lockspire/features/profiles/domain/profile_registry.dart';
import 'package:lockspire/features/profiles/infrastructure/local_profile_data_adapter.dart';
import 'package:lockspire/features/profiles/infrastructure/secure_storage_profile_registry_adapter.dart';
import 'package:lockspire/features/profiles/presentation/start_profile.dart';
import 'package:lockspire/shared/profile_paths.dart';
import 'package:lockspire/shared/profile_scoped_secure_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  late Map<String, String> stored;
  const device = FlutterSecureStorage();

  setUp(() {
    stored = {};
    FlutterSecureStorage.setMockInitialValues(stored);
  });

  Future<Map<String, String>> raw() => device.readAll();

  group('ProfileScopedSecureStorage (ADR 0039)', () {
    const main = ProfileScopedSecureStorage(mainProfileId);
    const maria = ProfileScopedSecureStorage('p2');

    test('el principal conserva las claves de siempre; los demás llevan su '
        'prefijo', () async {
      await main.write(key: 'sync.webdav.password', value: 'mía');
      await maria.write(key: 'sync.webdav.password', value: 'suya');

      expect(await raw(), {
        'sync.webdav.password': 'mía',
        'profile.p2.sync.webdav.password': 'suya',
      });
      expect(await main.read(key: 'sync.webdav.password'), 'mía');
      expect(await maria.read(key: 'sync.webdav.password'), 'suya');
      expect(await maria.containsKey(key: 'otra'), isFalse);
    });

    test('readAll y deleteAll ven solo lo del perfil: nunca lo de otro ni la '
        'lista de perfiles', () async {
      await main.write(key: 'a', value: '1');
      await maria.write(key: 'a', value: '2');
      await device.write(key: 'device.profiles', value: '{}');

      expect(await main.readAll(), {'a': '1'});
      expect(await maria.readAll(), {'a': '2'});

      await main.deleteAll();
      expect(await raw(), {'profile.p2.a': '2', 'device.profiles': '{}'});

      await maria.delete(key: 'a');
      expect(await raw(), {'device.profiles': '{}'});
    });
  });

  group('SecureStorageProfileRegistryAdapter', () {
    const adapter = SecureStorageProfileRegistryAdapter(device);

    test(
      'sin nada guardado, la instalación de siempre; guarda y lee',
      () async {
        final initial = await adapter.load(mainName: '');
        expect(initial.profiles.single.isMain, isTrue);

        await adapter.save(initial.add(id: 'p2', name: 'María'));
        final read = await adapter.load(mainName: '');
        expect(read.profiles.map((p) => p.name), ['', 'María']);
        expect(read.lastUsedId, 'p2');
        expect(stored.keys, [SecureStorageProfileRegistryAdapter.key]);
      },
    );

    test('si la lista se corrompe, vuelve al principal', () async {
      await device.write(
        key: SecureStorageProfileRegistryAdapter.key,
        value: 'no es json',
      );
      final read = await adapter.load(mainName: 'Principal');
      expect(read.profiles.single.isMain, isTrue);
    });
  });

  group('LocalProfileDataAdapter', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('lockspire_prof_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('borra la carpeta y las claves del perfil, y nada más', () async {
      final vault = File(vaultFilePathFor(dir.path, 'p2'))
        ..createSync(recursive: true)
        ..writeAsStringSync('bóveda de María');
      final mainVault = File(vaultFilePathFor(dir.path, mainProfileId))
        ..writeAsStringSync('mi bóveda');
      await const ProfileScopedSecureStorage('p2').write(key: 'k', value: '1');
      await const ProfileScopedSecureStorage('p3').write(key: 'k', value: '2');
      await const ProfileScopedSecureStorage(
        mainProfileId,
      ).write(key: 'k', value: '3');

      await LocalProfileDataAdapter(device, () async => dir.path).erase('p2');

      expect(vault.existsSync(), isFalse);
      expect(Directory(profileDirectory(dir.path, 'p2')).existsSync(), isFalse);
      expect(mainVault.readAsStringSync(), 'mi bóveda');
      expect(await raw(), {'profile.p3.k': '2', 'k': '3'});
    });

    test('nunca borra el principal', () async {
      final adapter = LocalProfileDataAdapter(device, () async => dir.path);
      await expectLater(adapter.erase(mainProfileId), throwsArgumentError);
      await expectLater(adapter.erase(''), throwsArgumentError);
    });
  });

  test('las bóvedas: el principal donde siempre, los demás en su carpeta', () {
    expect(
      vaultFilePathFor('/datos', mainProfileId),
      p.join('/datos', 'vault.lockspire'),
    );
    expect(
      vaultFilePathFor('/datos', 'p2'),
      p.join('/datos', 'profiles', 'p2', 'vault.lockspire'),
    );
  });

  group('startProfileId', () {
    const adapter = SecureStorageProfileRegistryAdapter(device);

    test(
      'abre el último usado si están activados; si no, el principal',
      () async {
        await adapter.save(
          ProfileRegistry.initial(mainName: '').add(id: 'p2', name: 'María'),
        );

        expect(
          await startProfileId(registry: adapter, enabledByDefault: true),
          'p2',
        );
        expect(
          await startProfileId(registry: adapter, enabledByDefault: false),
          mainProfileId,
        );
      },
    );
  });
}
