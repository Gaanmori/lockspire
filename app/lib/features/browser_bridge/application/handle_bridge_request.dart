// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire_bridge/lockspire_bridge.dart';

import 'bridge_app_requests.dart';
import 'bridge_credential_requests.dart';
import 'bridge_link_requests.dart';
import 'bridge_login_save_requests.dart';

export 'bridge_app_requests.dart';
export 'bridge_credential_requests.dart';
export 'bridge_link_requests.dart';
export 'bridge_login_save_requests.dart';

/// Responde las peticiones de la extensión (ADR 0013): elige, por el tipo,
/// quién la atiende. Cada tema vive en su propia clase (revisión
/// 2026-09-30, A11), así una función nueva de la extensión agrega un caso
/// acá y no toca las demás. No sabe nada de transporte ni de Riverpod.
class HandleBridgeRequest {
  final BridgeAppRequests app;
  final BridgeCredentialRequests credentials;
  final BridgeLinkRequests links;
  final BridgeLoginSaveRequests logins;

  const HandleBridgeRequest({
    required this.app,
    required this.credentials,
    required this.links,
    required this.logins,
  });

  Future<Map<String, Object?>> call(BridgeRequest request) async =>
      switch (request) {
        PingRequest() => app.ping(request),
        ShowAppRequest() => app.show(request),
        GeneratePasswordRequest() => app.generate(request),
        GetCredentialsRequest() => credentials.forOrigin(request),
        ListCredentialsRequest() => credentials.all(request),
        GetCredentialSecretRequest() => credentials.secret(request),
        RequestLinkOriginRequest() => links.link(request),
        CheckLoginRequest() => await logins.check(request),
        SaveLoginRequest() => await logins.save(request),
        NeverSaveForOriginRequest() => await logins.never(request),
      };
}
