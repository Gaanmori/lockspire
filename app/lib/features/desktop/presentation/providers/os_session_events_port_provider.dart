// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io' show Platform;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/os_session_events_port.dart';
import '../../infrastructure/linux_os_session_events_adapter.dart';
import '../../infrastructure/no_os_session_events_adapter.dart';
import '../../infrastructure/windows_os_session_events_adapter.dart';

part 'os_session_events_port_provider.g.dart';

@Riverpod(keepAlive: true)
OsSessionEventsPort osSessionEventsPort(Ref ref) {
  final OsSessionEventsPort port;
  if (Platform.isWindows) {
    port = WindowsOsSessionEventsAdapter();
  } else if (Platform.isLinux) {
    port = LinuxOsSessionEventsAdapter();
  } else {
    port = NoOsSessionEventsAdapter();
  }
  ref.onDispose(port.dispose);
  return port;
}
