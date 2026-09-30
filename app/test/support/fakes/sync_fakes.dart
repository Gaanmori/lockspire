// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:lockspire/features/sync/domain/ports/cloud_sign_in_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_state_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/sync/domain/ports/active_sync_provider_port.dart';

/// Remoto falso en memoria para tests — no hace red real.
class FakeSyncPort implements SyncPort {
  VaultFile? remoteFile;

  /// Cuántas veces se llamó [uploadVault] — algunos tests lo usan para
  /// confirmar que un debounce colapsó varios disparos en una sola sync.
  int uploadVaultCalls = 0;

  /// Sin conexión: toda operación falla como falla la red.
  bool offline = false;

  void _checkOnline() {
    if (offline) throw const SocketException('Sin conexión (test)');
  }

  @override
  Future<bool> remoteVaultExists() async {
    _checkOnline();
    return remoteFile != null;
  }

  @override
  Future<VaultFile> downloadVault() async {
    _checkOnline();
    final file = remoteFile;
    if (file == null) {
      throw StateError('No hay bóveda remota');
    }
    return file;
  }

  @override
  Future<void> uploadVault(VaultFile file) async {
    _checkOnline();
    uploadVaultCalls++;
    remoteFile = file;
  }
}

/// Estado de sync falso en memoria para tests.
class FakeSyncStatePort implements SyncStatePort {
  String? _lastSyncedHash;

  @override
  Future<String?> lastSyncedHash() async => _lastSyncedHash;

  @override
  Future<void> saveLastSyncedHash(String hash) async {
    _lastSyncedHash = hash;
  }

  bool passwordChangedElsewhereFlag = false;

  @override
  Future<bool> passwordChangedElsewhere() async => passwordChangedElsewhereFlag;

  @override
  Future<void> setPasswordChangedElsewhere(bool value) async {
    passwordChangedElsewhereFlag = value;
  }
}

/// Nube activa en memoria. [active] arranca con la que se pase.
class FakeActiveSyncProviderPort implements ActiveSyncProviderPort {
  SyncProviderId? active;

  FakeActiveSyncProviderPort([this.active]);

  @override
  Future<SyncProviderId?> activeProvider() async => active;

  @override
  Future<void> saveActiveProvider(SyncProviderId id) async => active = id;

  @override
  Future<void> clearActiveProvider() async => active = null;
}

/// Iniciar sesión en una nube sin OAuth real (A12): [account] es la cuenta
/// que "elige" el usuario; [error], que el inicio de sesión falla.
class FakeCloudSignIn implements CloudSignInPort {
  CloudSignIn account;
  Object? error;
  bool disconnected = false;

  FakeCloudSignIn(this.account);

  @override
  Future<CloudSignIn> connect() async {
    if (error case final e?) throw e;
    disconnected = false;
    return account;
  }

  @override
  Future<void> disconnect() async => disconnected = true;
}
