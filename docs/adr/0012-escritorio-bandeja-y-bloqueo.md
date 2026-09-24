# 0012 — Escritorio: la app vive en la bandeja del sistema y no se bloquea al ocultarse

- Estado: Aceptado
- Fecha: 2026-09-24
- Reemplaza parcialmente: [ADR 0008](0008-sesion-auto-lock.md), disparador 2 ("app en segundo plano"), **solo en escritorio** (Windows y Linux). En Android, ADR 0008 sigue vigente sin cambios.

## Contexto

[ADR 0005](0005-protocolo-native-messaging.md) define que la extensión de navegador obtiene credenciales de la app Flutter, que "corre en background y mantiene la bóveda desbloqueada en memoria durante la sesión". Hoy eso es imposible en escritorio:

- ADR 0008 bloquea la bóveda en `AppLifecycleState.hidden`/`.paused`. En escritorio Flutter reporta `hidden` al **minimizar** la ventana, así que la bóveda se bloquea en cuanto el usuario vuelve al navegador minimizando Lockspire.
- Cerrar la ventana termina el proceso: no queda nadie escuchando el IPC del native host.

Resultado: la extensión solo funcionaría con la ventana de Lockspire visible, lo cual no es usable. El usuario eligió explícitamente el modelo estándar de gestores de escritorio (KeePassXC, Bitwarden desktop): la app vive en la bandeja y el bloqueo depende de inactividad y de eventos de la sesión del SO, no de la visibilidad de la ventana.

## Decisión

Aplica solo a Windows y Linux (plataformas de escritorio soportadas). macOS queda fuera por no ser plataforma objetivo todavía.

### Ciclo de vida de la ventana

- **Cerrar la ventana (X) la oculta en la bandeja**, no termina el proceso (`window_manager.setPreventClose(true)` + `hide()` en `onWindowClose`). El primer cierre muestra una notificación/snackbar única explicando que Lockspire sigue en la bandeja.
- **Icono en la bandeja** (`tray_manager`) con menú: *Abrir Lockspire*, *Bloquear* (solo si está desbloqueada) y *Salir*. Clic en el icono = abrir.
- **Salir** bloquea la bóveda (descarta la clave de memoria) y termina el proceso de verdad.
- Minimizar u ocultar **no bloquea**. Los estados `hidden`/`paused` se ignoran en escritorio.

### Qué bloquea la bóveda en escritorio

1. **Inactividad**: el mismo temporizador de 5 minutos de ADR 0008, que sigue corriendo con la ventana oculta. Solo cuenta como actividad la interacción del usuario con la UI de Lockspire (puntero, scroll, teclado — sin cambios respecto a ADR 0008).
   - **Las peticiones de la extensión NO reinician el temporizador.** Si lo hicieran, navegar por la web mantendría la bóveda abierta indefinidamente sin que el usuario toque Lockspire. Consecuencia aceptada: tras 5 minutos sin tocar la app, el siguiente autocompletado pide desbloquear.
2. **Bloqueo manual**: botón *Bloquear* de la app o del menú de la bandeja.
3. **Bloqueo de la sesión del SO y suspensión**, inmediato:
   - **Windows:** `WTSRegisterSessionNotification` → `WM_WTSSESSION_CHANGE` con `WTS_SESSION_LOCK`, y `WM_POWERBROADCAST` con `PBT_APMSUSPEND`. Se capturan en el runner nativo (`windows/runner/flutter_window.cpp`) y se reenvían a Dart por un `MethodChannel` (`com.lockspire/os_session`).
   - **Linux:** D-Bus (paquete `dbus`, Dart puro): señal `Lock` de la sesión de `org.freedesktop.login1`, `PrepareForSleep(true)` del `Manager` de login1, y `ActiveChanged(true)` de los salvapantallas `org.freedesktop.ScreenSaver`, `org.gnome.ScreenSaver` y `org.cinnamon.ScreenSaver` (Linux Mint).
   - Abstraído tras un puerto `OsSessionEventsPort` en `vault/domain` con un adaptador por plataforma, más uno nulo para el resto.
4. **Salir** de la app (ver arriba).

### Una sola instancia

Con la app viviendo en la bandeja, abrirla de nuevo desde el menú del SO no debe arrancar un segundo proceso: habría dos procesos escribiendo el mismo archivo de bóveda y compitiendo por el IPC del native host. La segunda instancia debe pedirle a la primera que muestre su ventana y terminar. Se implementa sobre el mismo canal IPC local de [ADR 0013](0013-native-host-dart-e-ipc.md) (la primera instancia ya lo escucha), no con un mecanismo aparte.

### Dependencias

- `window_manager` (interceptar cierre, mostrar/ocultar/enfocar).
- `tray_manager` **fijado a 0.5.x**: desde 0.6 depende de `nativeapi`/`cnativeapi` (~2 MB de C++ de propósito general que expone muchas APIs del sistema), superficie de supply chain injustificada para un icono de bandeja. 0.5.x es un plugin clásico; en Linux usa `libayatana-appindicator3`.
- `dbus` (Canonical, Dart puro) para los eventos de sesión en Linux.

## Consecuencias

- **Más tiempo con la clave en memoria.** Antes, ocultar la ventana bloqueaba de inmediato; ahora la bóveda puede quedar desbloqueada hasta 5 minutos con la ventana oculta. Esto amplía la ventana del adversario 4 de `docs/THREAT_MODEL.md` (malware local con privilegios de usuario). Se acota con los disparadores 1–3 y se documenta allí. No cambia nada en reposo ni en la nube.
- **Linux depende del entorno de escritorio** para detectar el bloqueo de pantalla: si ninguno de los servicios D-Bus listados emite la señal (entornos minimalistas, sin logind), solo quedan inactividad y bloqueo manual. Limitación conocida y aceptada, no silenciosa: está documentada aquí.
- **GNOME sin la extensión AppIndicator** no muestra iconos de bandeja. La ventana sigue funcionando; solo falta el icono. Linux Mint (Cinnamon), KDE y Ubuntu (extensión habilitada por defecto) sí lo muestran.
- Dependencias nativas nuevas para compilar en Linux: `libayatana-appindicator3-dev`.

## Alternativas consideradas

- **Mantener el bloqueo al minimizar** (la extensión solo funciona con la ventana visible). Descartado por el usuario: hace inusable la extensión.
- **Bandeja + temporizador más corto (p. ej. 1 minuto) mientras está oculta.** Descartado por el usuario a favor de un único temporizador de 5 minutos; se puede revisar cuando exista una pantalla de ajustes con timeout configurable.
- **Que las peticiones de la extensión cuenten como actividad.** Descartado: la bóveda no se bloquearía nunca mientras el usuario navega.
- **`tray_manager` ≥ 0.6.** Ver "Dependencias".
