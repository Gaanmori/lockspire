// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import '../../domain/entities/vault_entry.dart';

/// Nombres e íconos de cada tipo de entrada (ADR 0025).
extension VaultEntryTypeLabel on VaultEntryType {
  String get label => switch (this) {
    VaultEntryType.card => 'tarjeta',
    VaultEntryType.document => 'documento',
    VaultEntryType.note => 'nota',
    VaultEntryType.passkey => 'passkey',
    VaultEntryType.password => 'contraseña',
  };

  IconData get icon => switch (this) {
    VaultEntryType.card => Icons.credit_card,
    VaultEntryType.document => Icons.badge_outlined,
    VaultEntryType.note => Icons.sticky_note_2_outlined,
    _ => Icons.key_outlined,
  };
}
