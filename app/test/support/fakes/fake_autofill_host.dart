// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/autofill/domain/autofill_session.dart';
import 'package:lockspire/features/autofill/domain/ports/autofill_host_port.dart';

/// La actividad de autocompletado de Android en memoria: [nextRequest] es lo
/// que pide el sistema; el resto registra la respuesta.
class FakeAutofillHost implements AutofillHostPort {
  AutofillRequest nextRequest = const AutofillUnknownRequest();
  ({String username, String password})? filled;
  bool saved = false;
  bool cancelled = false;
  List<AutofillSessionItem>? sessionItems;

  @override
  Future<AutofillRequest> request() async => nextRequest;

  @override
  Future<void> startSession({
    required Duration ttl,
    required Set<String> trustedBrowsers,
    required List<AutofillSessionItem> items,
  }) async => sessionItems = items;

  @override
  Future<void> fill({
    required String username,
    required String password,
  }) async => filled = (username: username, password: password);

  @override
  Future<void> confirmSaved() async => saved = true;

  @override
  Future<void> cancel() async => cancelled = true;
}
