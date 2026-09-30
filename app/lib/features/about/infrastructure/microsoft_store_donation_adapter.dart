// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/ports/donation_port.dart';
import 'donation_products.dart';

/// Donaciones con complementos consumibles de Microsoft Store (ADR 0035),
/// por el canal `com.lockspire.lockspire/store_donations` del runner de
/// Windows (`windows/runner/store_donations.cpp`). Solo responde en la app
/// instalada desde la Store; fuera de ella no hay opciones.
class MicrosoftStoreDonationAdapter implements DonationPort {
  final MethodChannel _channel;
  var _storeIds = <DonationTier, String>{};

  /// Al crearse (al arrancar la app) confirma las compras que quedaron sin
  /// confirmar: si no, no se podría volver a donar ese monto.
  MicrosoftStoreDonationAdapter({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.lockspire.lockspire/store_donations') {
    unawaited(
      _channel
          .invokeMethod<int>('fulfillPending')
          .then<void>(
            (_) {},
            onError: (Object _) {}, // Sin la Store no hay nada que confirmar.
          ),
    );
  }

  @override
  Future<List<DonationOffer>> offers() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'offers',
    );
    final byToken = {
      for (final product in raw ?? const <Map<Object?, Object?>>[])
        if (product['token'] case final String token) token: product,
    };
    final offers = <DonationOffer>[];
    final storeIds = <DonationTier, String>{};
    for (final MapEntry(key: tier, value: id) in donationProductIds.entries) {
      final product = byToken[id];
      if (product?['storeId'] case final String storeId) {
        storeIds[tier] = storeId;
        offers.add(
          DonationOffer(tier: tier, price: product!['price'] as String?),
        );
      }
    }
    _storeIds = storeIds;
    return offers;
  }

  @override
  Future<DonationOutcome> donate(DonationTier tier) async {
    if (!_storeIds.containsKey(tier)) await offers();
    final storeId = _storeIds[tier];
    if (storeId == null) return DonationOutcome.failed;
    try {
      final status = await _channel.invokeMethod<String>('purchase', storeId);
      return switch (status) {
        // "Ya comprado": una donación anterior que quedó sin confirmar; el
        // runner la confirma ahora.
        'succeeded' || 'alreadyPurchased' => DonationOutcome.paid,
        'notPurchased' => DonationOutcome.cancelled,
        _ => DonationOutcome.failed,
      };
    } on PlatformException {
      return DonationOutcome.failed;
    }
  }
}
