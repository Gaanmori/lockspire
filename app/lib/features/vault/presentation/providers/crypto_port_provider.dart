// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/crypto_port.dart';
import '../../infrastructure/sodium_crypto_adapter.dart';
import 'sodium_provider.dart';

part 'crypto_port_provider.g.dart';

/// Composition root: inyecta el adaptador real de [CryptoPort] (ver ADR
/// 0003 — Riverpod actúa como composition root).
@Riverpod(keepAlive: true)
Future<CryptoPort> cryptoPort(Ref ref) async {
  final sodium = await ref.watch(sodiumProvider.future);
  return SodiumCryptoAdapter(sodium);
}
