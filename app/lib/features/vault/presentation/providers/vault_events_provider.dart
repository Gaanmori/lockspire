// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/vault_event.dart';

part 'vault_events_provider.g.dart';

/// Canal de [VaultEvent] de la sesión (hallazgo A3).
@Riverpod(keepAlive: true)
VaultEventBus vaultEvents(Ref ref) {
  final bus = VaultEventBus();
  ref.onDispose(bus._close);
  return bus;
}

class VaultEventBus {
  final _controller = StreamController<VaultEvent>.broadcast();

  Stream<VaultEvent> get events => _controller.stream;

  void emit(VaultEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void _close() => _controller.close();
}
