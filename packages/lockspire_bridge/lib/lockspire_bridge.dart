// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Protocolo y transporte IPC entre la app Lockspire y su native messaging
/// host (ADR 0005, ADR 0013).
library;

export 'src/ipc/bridge_client.dart';
export 'src/ipc/bridge_server.dart';
export 'src/ipc/connection_session.dart'
    show BridgeRequestHandler, ConnectionSession, SessionReply;
export 'src/ipc/ipc_location.dart';
export 'src/protocol/framing.dart';
export 'src/protocol/messages.dart';
export 'src/protocol/protocol_exception.dart';
