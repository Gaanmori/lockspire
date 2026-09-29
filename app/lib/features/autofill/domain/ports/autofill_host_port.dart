// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../autofill_session.dart';

/// Lo que pide Android a Lockspire (ADR 0011).
sealed class AutofillRequest {
  /// La app que muestra el formulario.
  final String packageName;

  /// Origen web (`https://sitio`) si el formulario está en una página;
  /// `null` en una app nativa.
  final String? origin;

  const AutofillRequest({required this.packageName, required this.origin});
}

/// Rellenar un inicio de sesión con una credencial guardada.
class AutofillFillRequest extends AutofillRequest {
  const AutofillFillRequest({
    required super.packageName,
    required super.origin,
  });
}

/// Guardar una credencial que el usuario acaba de escribir.
class AutofillSaveRequest extends AutofillRequest {
  final String username;
  final String password;

  const AutofillSaveRequest({
    required super.packageName,
    required super.origin,
    required this.username,
    required this.password,
  });
}

/// Un pedido que esta versión no entiende.
class AutofillUnknownRequest extends AutofillRequest {
  const AutofillUnknownRequest() : super(packageName: '', origin: null);
}

/// La actividad de autocompletado de Android que abrió Lockspire: de ahí
/// sale el pedido y ahí vuelve la respuesta. La parte nativa nunca ve la
/// bóveda, solo el resultado (ADR 0011).
abstract class AutofillHostPort {
  Future<AutofillRequest> request();

  /// Durante [ttl], el servicio nativo ofrece directamente estas cuentas
  /// sin volver a pedir desbloqueo (ADR 0026).
  Future<void> startSession({
    required Duration ttl,
    required Set<String> trustedBrowsers,
    required List<AutofillSessionItem> items,
  });

  /// Rellena el formulario y cierra.
  Future<void> fill({required String username, required String password});

  /// La credencial nueva ya se guardó: cierra.
  Future<void> confirmSaved();

  /// Cierra sin hacer nada.
  Future<void> cancel();
}
