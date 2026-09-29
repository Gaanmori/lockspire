// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;

import 'features/appearance/presentation/appearance_controller.dart';
import 'features/appearance/presentation/launcher_icon_sync.dart';
import 'features/appearance/presentation/providers/system_accent_color_provider.dart';
import 'features/sync/presentation/auto_sync_controller.dart';
import 'features/vault/presentation/auto_lock_controller.dart';
import 'features/vault/presentation/providers/auto_lock_timeout_setting_provider.dart';
import 'features/vault/presentation/site_icons_controller.dart';

import 'features/sync/presentation/providers/sync_master_password_change_replica_provider.dart';
import 'features/sync/presentation/providers/sync_password_changed_elsewhere_provider.dart';
import 'features/vault/presentation/providers/master_password_change_replica_port_provider.dart';
import 'features/vault/presentation/providers/password_changed_elsewhere_port_provider.dart';

/// Conexiones entre features que la app hace en su composition root, para
/// que ninguna feature dependa de otra (revisión 2026-09-25, hallazgo A3).
/// Las usa `main.dart`; `test/app_composition_test.dart` verifica que estén.
List<Override> appOverrides() => [
  // Cambiar la contraseña maestra sincroniza antes y publica después (ADR
  // 0018): `vault` define el puerto y `sync` lo implementa.
  masterPasswordChangeReplicaPortProvider.overrideWith(
    (ref) => ref.watch(syncMasterPasswordChangeReplicaProvider.future),
  ),
  // Si la contraseña se cambió en otro dispositivo, al abrir se pide la
  // nueva, sin biometría (ADR 0024).
  passwordChangedElsewherePortProvider.overrideWith(
    (ref) => ref.watch(syncPasswordChangedElsewhereProvider.future),
  ),
];

/// Lo que la app carga antes del primer cuadro y los servicios que corren en
/// segundo plano. La usan `main()` y los tests de flujo, así prueban el
/// mismo arranque. [isAutofill]: la pantalla de autocompletado de Android
/// (ADR 0011), que no sincroniza.
Future<void> startApp(
  ProviderContainer container, {
  required bool isAutofill,
}) async {
  // El tema elegido se carga antes del primer frame: si no, la app
  // mostraría un instante el tema por defecto y luego cambiaría.
  await container.read(appearanceControllerProvider.future);
  await container.read(systemAccentColorProvider.future);
  // Igual con el tiempo de bloqueo (ADR 0016): el primer desbloqueo ya
  // usa el valor guardado.
  await container.read(autoLockTimeoutSettingProvider.future);
  // El bloqueo automático escucha la sesión desde el arranque, también en
  // la pantalla de autocompletado de Android (hallazgo A1).
  _keepRunning(container, autoLockControllerProvider);
  // La sync automática escucha los eventos de la bóveda (hallazgo A3).
  // No en el autocompletado de Android: rellenar no necesita la nube, y
  // conectar Google Drive ahí muestra la ventana "Iniciando sesión" encima
  // de la app que pide (ADR 0026). Lo guardado desde ahí se sube en la
  // próxima sync de la app.
  if (!isAutofill) {
    _keepRunning(container, autoSyncControllerProvider);
    // Íconos de los sitios, si están activados (ADR 0029).
    _keepRunning(container, siteIconsControllerProvider);
    // Ícono del lanzador de Android según el tema (ADR 0031).
    _keepRunning(container, launcherIconSyncProvider);
  }
}

/// Arranca un servicio en segundo plano y lo mantiene escuchado. Con solo
/// leerlo, Riverpod lo deja en pausa por no tener quien lo escuche, y lo que
/// él escucha deja de actualizarse: cambiar el tiempo de bloqueo no llegaba
/// al temporizador, que seguía con el anterior (encontrado por un test de
/// flujo, 2026-09-29).
void _keepRunning<T>(
  ProviderContainer container,
  ProviderListenable<T> provider,
) {
  container.listen<T>(provider, (_, _) {});
}
