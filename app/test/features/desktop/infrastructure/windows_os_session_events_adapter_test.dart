// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/desktop/infrastructure/no_os_session_events_adapter.dart';
import 'package:lockspire/features/desktop/infrastructure/windows_os_session_events_adapter.dart';

import '../../../support/fake_method_channel.dart';

/// Bloquear la sesión o suspender el equipo bloquea la bóveda (ADR 0012).
/// En Windows lo avisa el runner en C++ por `com.lockspire/os_session`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sesión bloqueada y suspensión piden bloquear; otros avisos '
      'no', () async {
    final adapter = WindowsOsSessionEventsAdapter();
    final runner = FakeMethodChannel(osSessionChannelName);
    var requests = 0;
    final subscription = adapter.lockRequests.listen((_) => requests++);

    await runner.emit('sessionLocked');
    await runner.emit('suspending');
    await runner.emit('sessionUnlocked');
    await pumpEventQueue();

    expect(requests, 2);
    await subscription.cancel();
    await adapter.dispose();
  });

  test('sin escritorio (Android) no hay avisos del sistema', () async {
    final adapter = NoOsSessionEventsAdapter();

    expect(await adapter.lockRequests.isEmpty, isTrue);
    await adapter.dispose();
  });
}
