// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/about/domain/ports/app_info_port.dart';
import 'package:lockspire/features/about/domain/ports/donation_port.dart';
import 'package:lockspire/features/about/domain/ports/external_link_port.dart';

class FakeAppInfo implements AppInfoPort {
  final AppVersion value;

  const FakeAppInfo([
    this.value = const AppVersion(version: '1.2.3', build: '45'),
  ]);

  @override
  Future<AppVersion> version() async => value;
}

/// Registra los enlaces abiertos; [canOpen] simula que no hay navegador.
class FakeExternalLinks implements ExternalLinkPort {
  final opened = <Uri>[];
  bool canOpen = true;

  @override
  Future<bool> open(Uri url) async {
    if (canOpen) opened.add(url);
    return canOpen;
  }
}

/// Donaciones en memoria (ADR 0033). Por defecto, como Google Play: tres
/// montos con precio y el pago dentro de la app; [outcome] es cómo termina.
class FakeDonations implements DonationPort {
  List<DonationOffer> available = [
    for (final (tier, price) in const [
      (DonationTier.coffee, r'$ 3.000'),
      (DonationTier.coffeeAndCake, r'$ 5.000'),
      (DonationTier.lunch, r'$ 10.000'),
    ])
      DonationOffer(tier: tier, price: price),
  ];
  DonationOutcome outcome = DonationOutcome.paid;
  final donated = <DonationTier>[];

  @override
  Future<List<DonationOffer>> offers() async => available;

  @override
  Future<DonationOutcome> donate(DonationTier tier) async {
    donated.add(tier);
    return outcome;
  }
}
