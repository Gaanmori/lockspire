// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../domain/ports/donation_port.dart';

/// Ids de los productos de donación (ADR 0033, 0035): los mismos en Play
/// Console y en Partner Center (como "id del producto" del complemento).
const donationProductIds = {
  DonationTier.coffee: 'donation_coffee',
  DonationTier.coffeeAndCake: 'donation_coffee_and_cake',
  DonationTier.lunch: 'donation_lunch',
};
