// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/entities/entry_fields.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/presentation/entry_form_model.dart';

import '../../../support/builders.dart';

/// Qué campos tiene el formulario de cada tipo y cómo se vuelven la entrada
/// (A15), sin montar la pantalla.
void main() {
  test('cada tipo tiene sus propios campos', () {
    expect(EntryFormModel.fixedKeysFor(VaultEntryType.password), [
      EntryFields.username,
      EntryFields.password,
    ]);
    expect(
      EntryFormModel.fixedKeysFor(VaultEntryType.card),
      contains(EntryFields.cardCvv),
    );
    expect(
      EntryFormModel.fixedKeysFor(VaultEntryType.document),
      contains(EntryFields.docNumber),
    );
  });

  test('una contraseña nueva arranca con un sitio vacío; una tarjeta no', () {
    final password = EntryFormModel(type: VaultEntryType.password);
    final card = EntryFormModel(type: VaultEntryType.card);
    addTearDown(password.dispose);
    addTearDown(card.dispose);

    expect(password.urls, hasLength(1));
    expect(card.urls, isEmpty);
  });

  test('guardar conserva lo que el formulario no maneja y quita lo que se '
      'vació', () {
    final form = EntryFormModel(
      entry: anEntry(
        username: 'ana',
        password: 'p',
        url: 'https://banco.ejemplo',
        fields: {'otra_app:dato': 'se conserva'},
      ),
      type: VaultEntryType.password,
    );
    addTearDown(form.dispose);

    form.fixed[EntryFields.username]!.text = '';
    form.password.text = 'nueva';
    form.notes.text = 'nota';

    final fields = form.toFields();
    expect(fields['otra_app:dato'], 'se conserva');
    expect(fields.containsKey(EntryFields.username), isFalse);
    expect(fields[EntryFields.password], 'nueva');
    expect(fields[EntryFields.url], 'https://banco.ejemplo');
    expect(fields[EntryFields.notes], 'nota');
  });
}
