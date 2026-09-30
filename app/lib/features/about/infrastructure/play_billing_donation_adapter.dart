// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/ports/donation_port.dart';

/// Donaciones con la facturación de Google Play (ADR 0033), solo en la
/// versión de Play: su política no permite enlazar pagos externos para
/// apoyar al desarrollador. Cada monto es un producto consumible, así que se
/// puede donar más de una vez. La app solo ve el resultado del pago.
class PlayBillingDonationAdapter implements DonationPort {
  /// Los productos que hay que crear en Play Console, con esos ids.
  static const productIds = {
    DonationTier.coffee: 'donation_coffee',
    DonationTier.coffeeAndCake: 'donation_coffee_and_cake',
    DonationTier.lunch: 'donation_lunch',
  };

  final InAppPurchase _store;
  final _updates = StreamController<PurchaseDetails>.broadcast();
  var _products = <DonationTier, ProductDetails>{};

  /// Escucha desde que se crea (al arrancar la app): un pago que quedó
  /// pendiente en una sesión anterior y se completa después también se
  /// confirma. Si no, Google Play lo reembolsa a los tres días.
  PlayBillingDonationAdapter(this._store) {
    _store.purchaseStream.listen(_onPurchases, onError: (Object _) {});
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      _updates.add(purchase);
    }
  }

  @override
  Future<List<DonationOffer>> offers() async {
    if (!await _store.isAvailable()) return const [];
    final response = await _store.queryProductDetails(
      productIds.values.toSet(),
    );
    final byId = {for (final p in response.productDetails) p.id: p};
    _products = {
      for (final MapEntry(key: tier, value: id) in productIds.entries)
        tier: ?byId[id],
    };
    return [
      for (final MapEntry(key: tier, value: product) in _products.entries)
        DonationOffer(tier: tier, price: product.price),
    ];
  }

  @override
  Future<DonationOutcome> donate(DonationTier tier) async {
    if (!_products.containsKey(tier)) await offers();
    final product = _products[tier];
    if (product == null) return DonationOutcome.failed;

    // Se escucha antes de abrir el pago para no perder la respuesta.
    final result = _updates.stream.firstWhere((p) => p.productID == product.id);
    final bool started;
    try {
      started = await _store.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      // Por ejemplo, otro pago del mismo producto sin terminar.
      result.ignore();
      return DonationOutcome.failed;
    }
    if (!started) {
      result.ignore();
      return DonationOutcome.failed;
    }
    return switch ((await result).status) {
      PurchaseStatus.purchased ||
      PurchaseStatus.restored => DonationOutcome.paid,
      PurchaseStatus.pending => DonationOutcome.pending,
      PurchaseStatus.canceled => DonationOutcome.cancelled,
      PurchaseStatus.error => DonationOutcome.failed,
    };
  }
}
