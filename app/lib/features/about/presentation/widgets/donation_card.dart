// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/features/vault/presentation/auto_lock_controller.dart';
import 'package:lockspire/l10n/l10n.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/ports/donation_port.dart';
import '../providers/about_providers.dart';

/// "Invíteme un café" (ADR 0033): tres montos. No aparece si en esta
/// versión no hay cómo donar.
class DonationCard extends ConsumerStatefulWidget {
  const DonationCard({super.key});

  @override
  ConsumerState<DonationCard> createState() => _DonationCardState();
}

class _DonationCardState extends ConsumerState<DonationCard> {
  /// Mientras un pago está abierto no se abre otro.
  bool _busy = false;

  Future<void> _donate(DonationTier tier) async {
    final port = ref.read(donationPortProvider);
    if (port == null || _busy) return;
    setState(() => _busy = true);
    final DonationOutcome outcome;
    try {
      // El pago abre la ventana de la tienda (ver whileInSystemUi).
      outcome = await ref
          .read(autoLockControllerProvider)
          .whileInSystemUi(() => port.donate(tier));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final l10n = context.l10n;
    final message = switch (outcome) {
      DonationOutcome.paid => l10n.aboutDonateThanks,
      DonationOutcome.pending => l10n.aboutDonatePending,
      DonationOutcome.failed => l10n.aboutDonateFailed,
      DonationOutcome.cancelled => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final port = ref.watch(donationPortProvider);
    final offers = ref.watch(donationOffersProvider).value ?? const [];
    if (port == null || offers.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: LockspireSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: LockspireSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: Text(l10n.aboutDonateTitle),
                subtitle: Text(l10n.aboutDonateBody),
              ),
              for (final offer in offers)
                ListTile(
                  enabled: !_busy,
                  leading: Icon(_icon(offer.tier)),
                  title: Text(_label(l10n, offer.tier)),
                  trailing: offer.price == null
                      ? null
                      : Text(offer.price!, style: textTheme.titleSmall),
                  onTap: () => _donate(offer.tier),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(DonationTier tier) => switch (tier) {
    DonationTier.coffee => Icons.coffee_outlined,
    DonationTier.coffeeAndCake => Icons.cake_outlined,
    DonationTier.lunch => Icons.lunch_dining_outlined,
  };

  static String _label(AppLocalizations l10n, DonationTier tier) =>
      switch (tier) {
        DonationTier.coffee => l10n.aboutDonateCoffee,
        DonationTier.coffeeAndCake => l10n.aboutDonateCoffeeAndCake,
        DonationTier.lunch => l10n.aboutDonateLunch,
      };
}
