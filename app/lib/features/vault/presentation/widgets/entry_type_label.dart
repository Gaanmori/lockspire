// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import '../../domain/entities/vault_entry.dart';

/// Ícono de cada tipo de entrada (ADR 0025). Los nombres están en los
/// textos traducidos (ADR 0032).
extension VaultEntryTypeLabel on VaultEntryType {
  IconData get icon => switch (this) {
    VaultEntryType.card => Icons.credit_card,
    VaultEntryType.document => Icons.badge_outlined,
    VaultEntryType.note => Icons.sticky_note_2_outlined,
    _ => Icons.key_outlined,
  };
}
