// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Acciones de un usuario sobre la app, para que los tests de flujo se lean
/// como un guion ("crea la bóveda, agrega una contraseña, bloquea…") en vez
/// de como una lista de toques. Patrón "robot" (page object): si cambia un
/// texto o un control, se arregla aquí y no en cada test.
///
/// Los textos son los de la app en español (ver `app_es.arb`).
class AppRobot {
  final WidgetTester tester;

  AppRobot(this.tester);

  /// Deja correr las animaciones hasta que se asienten, con un tope de
  /// [limit] de reloj simulado. `pumpAndSettle` sigue avanzando mientras haya
  /// una animación infinita (un indicador de carga detrás de un diálogo) y
  /// podía adelantar minutos en silencio, hasta disparar el bloqueo
  /// automático en medio del test.
  Future<void> settle({Duration limit = const Duration(seconds: 3)}) async {
    var elapsed = Duration.zero;
    const step = Duration(milliseconds: 100);
    do {
      await tester.pump(step);
      elapsed += step;
    } while (tester.binding.hasScheduledFrame && elapsed < limit);
  }

  /// Los textos visibles, para diagnosticar un test que falla.
  String visibleTexts() => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .join(' | ');

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> tapText(String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pump();
    await tester.tap(find.text(text).last);
    await settle();
  }

  /// Espera a que aparezca [finder]: con la criptografía real (tests de
  /// `integration_test`) desbloquear tarda segundos y no siempre hay una
  /// animación que haga esperar a `pumpAndSettle`.
  Future<void> waitFor(
    Finder finder, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) {
        throw TestFailure(
          'No apareció a tiempo: $finder. En pantalla: ${visibleTexts()}',
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle();
  }

  /// El "atrás" del sistema (botón o gesto de Android).
  Future<void> systemBack() async {
    await tester.binding.handlePopRoute();
    await settle();
  }

  /// Desplaza la lista principal hasta que [finder] exista: las listas se
  /// construyen por partes y lo que está más abajo todavía no existe.
  Future<void> reveal(Finder finder) async {
    if (finder.evaluate().isNotEmpty) return;
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await settle();
  }

  /// Toca el botón principal con [label], llevándolo antes a la vista.
  Future<void> tapButton(String label) async {
    await reveal(find.widgetWithText(FilledButton, label));
    final button = find.widgetWithText(FilledButton, label).last;
    await tester.ensureVisible(button);
    await settle();
    await tester.tap(button);
    await settle();
  }

  Future<void> tapTooltip(String tooltip) async {
    await tester.tap(find.byTooltip(tooltip).first);
    await settle();
  }

  /// Toca el campo y escribe [text], como el usuario. Tocar primero importa
  /// con el binding real de `integration_test`: un campo que se deshabilitó
  /// un momento (p. ej. mientras se desbloqueaba) pierde la conexión con el
  /// método de entrada, y escribir sin enfocarlo de nuevo no llegaba.
  Future<void> type(String label, String text) async {
    await reveal(field(label));
    await tester.ensureVisible(field(label));
    await tester.tap(field(label));
    await tester.pump();
    await tester.enterText(field(label), text);
    await tester.pump();
  }

  // ── Bóveda ───────────────────────────────────────────────────────────

  Future<void> createVault(String password) async {
    await type('Contraseña maestra', password);
    await type('Confirmar contraseña', password);
    await tester.tap(find.widgetWithText(FilledButton, 'Crear bóveda'));
    await settle();
  }

  Future<void> unlock(String password) async {
    await type('Contraseña maestra', password);
    await tester.tap(find.widgetWithText(FilledButton, 'Desbloquear'));
    await settle();
  }

  /// En el teléfono "Bloquear" está en la barra de la pestaña Bóveda; en
  /// escritorio, al pie del riel.
  Future<void> lock() async {
    if (find.byTooltip('Bloquear').evaluate().isEmpty) {
      await tapText('Bóveda');
    }
    await tapTooltip('Bloquear');
  }

  // ── Entradas ─────────────────────────────────────────────────────────

  /// Abre el formulario de una contraseña nueva.
  Future<void> startNewPassword() async {
    await tapTooltip('Agregar');
    await tapText('Contraseña');
  }

  Future<void> addPassword({
    required String title,
    String? username,
    String? password,
  }) async {
    await startNewPassword();
    await type('Título', title);
    if (username != null) await type('Usuario', username);
    if (password != null) await type('Contraseña', password);
    await save();
  }

  Future<void> save() async {
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await settle();
  }

  Future<void> openEntry(String title) => tapText(title);

  Future<void> search(String query) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar por título, usuario o sitio'),
      query,
    );
    await settle();
  }

  // ── Sincronización ───────────────────────────────────────────────────

  Future<void> openSync() => tapText('Sincronización');

  Future<void> configureWebdav({
    String url = 'https://nube.ejemplo/dav',
    String user = 'ana',
    String password = 'clave-webdav',
  }) async {
    await type('URL del servidor WebDAV', url);
    await type('Usuario', user);
    await type('Contraseña', password);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await settle();
  }

  Future<void> syncNow() async {
    await tester.ensureVisible(find.text('Sincronizar ahora'));
    await tapText('Sincronizar ahora');
  }

  // ── Ajustes ──────────────────────────────────────────────────────────

  Future<void> openSettings() => tapText('Ajustes');
}
