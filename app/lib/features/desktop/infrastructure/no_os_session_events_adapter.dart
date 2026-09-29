// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../domain/ports/os_session_events_port.dart';

/// [OsSessionEventsPort] para plataformas sin shell de escritorio
/// (Android usa el bloqueo al pasar a segundo plano de ADR 0008).
class NoOsSessionEventsAdapter implements OsSessionEventsPort {
  @override
  Stream<void> get lockRequests => const Stream.empty();

  @override
  Future<void> dispose() async {}
}
