// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vault.dart';
import '../vault_session_controller.dart';

/// Confirmación mínima de que la bóveda quedó desbloqueada — la gestión
/// real de entradas es una feature futura, fuera de esta fase.
class VaultUnlockedScreen extends ConsumerWidget {
  final Vault vault;

  const VaultUnlockedScreen({super.key, required this.vault});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lockspire'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock),
            tooltip: 'Bloquear',
            onPressed: () =>
                ref.read(vaultSessionControllerProvider.notifier).lock(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_open, size: 48),
            const SizedBox(height: 16),
            const Text('Bóveda desbloqueada'),
            const SizedBox(height: 8),
            Text(
              '${vault.entries.length} entradas · ${vault.folders.length} carpetas',
            ),
          ],
        ),
      ),
    );
  }
}
