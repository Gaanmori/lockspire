// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/handle_bridge_request.dart';

part 'pending_link_request_provider.g.dart';

/// Vincular un sitio a una entrada, pedido desde la extensión y a la
/// espera de que el usuario lo confirme en la ventana de la app (ADR
/// 0015). Una sola a la vez: una petición nueva reemplaza a la anterior.
@Riverpod(keepAlive: true)
class PendingLinkRequest extends _$PendingLinkRequest {
  @override
  LinkRequest? build() => null;

  void set(LinkRequest request) => state = request;

  void clear() => state = null;
}
