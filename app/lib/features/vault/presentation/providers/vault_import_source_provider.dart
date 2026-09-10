// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/vault_import_source.dart';
import '../../infrastructure/safeincloud_xml_import_source.dart';

part 'vault_import_source_provider.g.dart';

/// Composition root: inyecta el adaptador real de [VaultImportSource] (ver
/// ADR 0003 — Riverpod actúa como composition root).
@Riverpod(keepAlive: true)
VaultImportSource vaultImportSource(Ref ref) => SafeInCloudXmlImportSource();
