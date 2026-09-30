// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/widgets.dart';

import '../../../../design/lockspire_spacing.dart';

/// La tarjeta de crear o desbloquear la bóveda con algo encima, p. ej. la
/// lista de perfiles (ADR 0039). Sin [header], solo la tarjeta.
class HeaderedCard extends StatelessWidget {
  final Widget? header;
  final Widget card;

  const HeaderedCard({super.key, required this.header, required this.card});

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    if (header == null) return card;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        const SizedBox(height: LockspireSpacing.md),
        card,
      ],
    );
  }
}
