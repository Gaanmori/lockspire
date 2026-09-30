// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/about/domain/ports/donation_port.dart';
import 'package:lockspire/features/about/infrastructure/microsoft_store_donation_adapter.dart';

import '../../../support/fake_method_channel.dart';

Map<String, String> _addOn(String token, String storeId, String price) => {
  'token': token,
  'storeId': storeId,
  'price': price,
};

/// Complementos de Microsoft Store (ADR 0035): el runner de Windows en C++,
/// simulado por su canal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMethodChannel runner;
  late MicrosoftStoreDonationAdapter adapter;

  setUp(() {
    runner = FakeMethodChannel('com.lockspire.lockspire/store_donations')
      ..answer('fulfillPending', 0)
      ..answer('offers', [
        _addOn('donation_lunch', '9NLUNCH', r'$ 40.000'),
        _addOn('otro_complemento', '9NOTRO', r'$ 1'),
        _addOn('donation_coffee', '9NCOFFEE', r'$ 12.000'),
      ]);
    adapter = MicrosoftStoreDonationAdapter(channel: runner.channel);
  });

  test('al crearse confirma las compras que quedaron sin confirmar', () async {
    await pumpEventQueue();

    expect(runner.methods.first, 'fulfillPending');
  });

  test('ofrece solo los complementos de donación, en orden y con el precio '
      'de la Store', () async {
    final offers = await adapter.offers();

    expect(offers.map((o) => (o.tier, o.price)), [
      (DonationTier.coffee, r'$ 12.000'),
      (DonationTier.lunch, r'$ 40.000'),
    ]);
  });

  test('compra por el id de la Store y traduce el resultado', () async {
    for (final (status, outcome) in [
      ('succeeded', DonationOutcome.paid),
      ('alreadyPurchased', DonationOutcome.paid),
      ('notPurchased', DonationOutcome.cancelled),
      ('networkError', DonationOutcome.failed),
      ('serverError', DonationOutcome.failed),
    ]) {
      runner.answer('purchase', status);
      expect(await adapter.donate(DonationTier.lunch), outcome, reason: status);
    }
    expect(runner.argumentsOf('purchase'), '9NLUNCH');
  });

  test('un complemento que no existe en Partner Center no abre ningún '
      'pago', () async {
    expect(
      await adapter.donate(DonationTier.coffeeAndCake),
      DonationOutcome.failed,
    );
    expect(runner.methods, isNot(contains('purchase')));
  });

  test('un error del runner es "no se pudo", nunca una excepción', () async {
    runner.fail('purchase');

    expect(await adapter.donate(DonationTier.coffee), DonationOutcome.failed);
  });

  test('fuera de la Store no hay opciones', () async {
    runner.answer('offers', <Object>[]);

    expect(await adapter.offers(), isEmpty);
  });
}
