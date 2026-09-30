// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/app_info_port.dart';
import '../../domain/ports/donation_port.dart';
import '../../domain/ports/external_link_port.dart';
import '../../infrastructure/donation_config.dart';
import '../../infrastructure/microsoft_store_donation_adapter.dart';
import '../../infrastructure/package_info_adapter.dart';
import '../../infrastructure/play_billing_donation_adapter.dart';
import '../../infrastructure/url_launcher_link_adapter.dart';

part 'about_providers.g.dart';

@Riverpod(keepAlive: true)
AppInfoPort appInfoPort(Ref ref) => const PackageInfoAdapter();

@Riverpod(keepAlive: true)
ExternalLinkPort externalLinkPort(Ref ref) => const UrlLauncherLinkAdapter();

/// Versión instalada, para mostrarla en Acerca de.
@Riverpod(keepAlive: true)
Future<AppVersion> appVersion(Ref ref) =>
    ref.watch(appInfoPortProvider).version();

/// Cómo se dona: con el pago de la tienda de esta compilación, Google Play
/// (ADR 0033) o Microsoft Store (ADR 0035); `null` en las demás. Se crea al
/// arrancar para confirmar los pagos que quedaron pendientes.
@Riverpod(keepAlive: true)
DonationPort? donationPort(Ref ref) {
  if (isGooglePlayBuild) {
    return PlayBillingDonationAdapter(InAppPurchase.instance);
  }
  if (isMicrosoftStoreBuild) return MicrosoftStoreDonationAdapter();
  return null;
}

/// Los montos para donar, con su precio; vacía si no se puede donar.
@Riverpod(keepAlive: true)
Future<List<DonationOffer>> donationOffers(Ref ref) async {
  final port = ref.watch(donationPortProvider);
  if (port == null) return const [];
  try {
    return await port.offers();
  } catch (_) {
    // Sin la tienda o sin conexión: la sección simplemente no aparece.
    return const [];
  }
}
