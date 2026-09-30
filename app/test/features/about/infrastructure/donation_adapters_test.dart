// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lockspire/features/about/domain/ports/donation_port.dart';
import 'package:lockspire/features/about/infrastructure/donation_products.dart';
import 'package:lockspire/features/about/infrastructure/play_billing_donation_adapter.dart';

ProductDetails _product(String id, String price) => ProductDetails(
  id: id,
  title: id,
  description: '',
  price: price,
  rawPrice: 0,
  currencyCode: 'COP',
);

PurchaseDetails _purchase(String productId, PurchaseStatus status) =>
    PurchaseDetails(
      productID: productId,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'google_play',
      ),
      transactionDate: null,
      status: status,
    )..pendingCompletePurchase = status == PurchaseStatus.purchased;

/// La facturación de Google Play en memoria: [answer] es lo que devuelve
/// Play cuando se abre un pago.
class _FakePlay implements InAppPurchase {
  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  Set<String> listed = donationProductIds.values.toSet();
  PurchaseStatus? answer = PurchaseStatus.purchased;
  Object? buyError;
  final bought = <String>[];
  final completed = <String>[];

  /// Play avisa de un pago (también de uno que quedó de otra sesión).
  void deliver(PurchaseDetails purchase) => _purchases.add([purchase]);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      for (final id in identifiers.intersection(listed))
        _product(id, '\$ ${id.length}.000'),
    ],
    notFoundIDs: identifiers.difference(listed).toList(),
  );

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    if (buyError case final error?) throw error;
    final id = purchaseParam.productDetails.id;
    bought.add(id);
    if (answer case final status?) {
      scheduleMicrotask(() => deliver(_purchase(id, status)));
    }
    return answer != null;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async =>
      completed.add(purchase.productID);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Donaciones con la facturación de Google Play (ADR 0033).
void main() {
  group('Google Play', () {
    late _FakePlay play;
    late PlayBillingDonationAdapter adapter;

    setUp(() {
      play = _FakePlay();
      adapter = PlayBillingDonationAdapter(play);
    });

    test('muestra los tres productos con el precio local de Play', () async {
      final offers = await adapter.offers();

      expect(offers.map((o) => o.tier), DonationTier.values);
      expect(offers.first.price, r'$ 15.000');
    });

    test('un producto que falta en Play Console no aparece; sin la tienda '
        'no hay opciones', () async {
      play.listed = {'donation_coffee'};
      expect((await adapter.offers()).map((o) => o.tier), [
        DonationTier.coffee,
      ]);

      play.available = false;
      expect(await adapter.offers(), isEmpty);
    });

    test('pagar confirma la compra (si no, Play la reembolsa) y se puede '
        'volver a donar', () async {
      expect(await adapter.donate(DonationTier.lunch), DonationOutcome.paid);
      expect(await adapter.donate(DonationTier.lunch), DonationOutcome.paid);

      expect(play.bought, ['donation_lunch', 'donation_lunch']);
      expect(play.completed, ['donation_lunch', 'donation_lunch']);
    });

    test('cancelado, pendiente y con error se distinguen', () async {
      play.answer = PurchaseStatus.canceled;
      expect(
        await adapter.donate(DonationTier.coffee),
        DonationOutcome.cancelled,
      );

      play.answer = PurchaseStatus.pending;
      expect(
        await adapter.donate(DonationTier.coffee),
        DonationOutcome.pending,
      );

      play.answer = PurchaseStatus.error;
      expect(await adapter.donate(DonationTier.coffee), DonationOutcome.failed);

      play.answer = null;
      expect(await adapter.donate(DonationTier.coffee), DonationOutcome.failed);

      play.buyError = PlatformException(code: 'itemAlreadyOwned');
      expect(await adapter.donate(DonationTier.coffee), DonationOutcome.failed);
    });

    test('un pago pendiente de otra sesión que se completa después se '
        'confirma igual', () async {
      play.deliver(_purchase('donation_coffee', PurchaseStatus.purchased));
      await pumpEventQueue();

      expect(play.completed, ['donation_coffee']);
    });

    test('un producto que no está en Play no abre ningún pago', () async {
      play.listed = {};

      expect(await adapter.donate(DonationTier.coffee), DonationOutcome.failed);
      expect(play.bought, isEmpty);
    });
  });
}
