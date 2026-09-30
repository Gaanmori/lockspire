// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Los tres montos de "Invíteme un café" (ADR 0033), de menor a mayor.
enum DonationTier { coffee, coffeeAndCake, lunch }

/// Una opción para donar, con su precio ya formateado por quien cobra
/// (Google Play lo da en la moneda local), o `null` si lo elige el donante.
class DonationOffer {
  final DonationTier tier;
  final String? price;

  const DonationOffer({required this.tier, this.price});
}

/// Cómo terminó el intento de donar.
enum DonationOutcome {
  /// El pago se completó dentro de la app (Google Play).
  paid,

  /// El pago quedó pendiente (por ejemplo, en efectivo en una tienda).
  pending,

  /// El donante cerró el pago.
  cancelled,

  /// No se pudo abrir el pago.
  failed,
}

/// Donaciones al desarrollador (ADR 0033). Nunca toca la bóveda.
abstract class DonationPort {
  /// Las opciones disponibles, en orden; vacía si no se puede donar desde
  /// aquí (por ejemplo, sin la tienda de Google Play).
  Future<List<DonationOffer>> offers();

  Future<DonationOutcome> donate(DonationTier tier);
}
