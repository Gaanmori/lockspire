# 0016 — Tiempo de bloqueo por inactividad configurable (1, 5 o 15 minutos)

- Estado: Aceptado
- Fecha: 2026-09-25
- Reemplaza parcialmente: [ADR 0008](0008-sesion-auto-lock.md), sección "Timeout: 5 minutos, fijo". El resto de ADR 0008 sigue vigente, y también [ADR 0012](0012-escritorio-bandeja-y-bloqueo.md).

## Contexto

ADR 0008 fijó el bloqueo por inactividad en 5 minutos y dejó expresamente la opción de configurarlo "para cuando exista una pantalla de ajustes". Con la app de escritorio en la bandeja (ADR 0012) y la extensión de navegador (ADR 0013), el usuario pidió poder elegir entre tres tiempos predeterminados.

## Decisión

Decisión del usuario ante opciones explícitas:

- **Tres valores fijos: 1, 5 y 15 minutos.** Por defecto 5, así que nada cambia para quien no toque el ajuste. No hay valor libre ni "nunca": un campo libre permitiría dejar la bóveda abierta indefinidamente.
- Se elige en **Seguridad → Bloqueo automático** y aplica igual en Windows, Linux y Android. Al cambiarlo, el temporizador se reinicia en ese momento con el valor nuevo.
- **Se guarda fuera de la bóveda**, en `flutter_secure_storage` (clave `session.auto_lock_timeout`), porque hace falta antes de desbloquear. No es un secreto. `main()` lo carga antes del primer frame.
- Sin cambios en qué cuenta como actividad (ADR 0008: puntero, scroll, teclado de la UI de Lockspire) ni en que las peticiones de la extensión **no** reinician el temporizador (ADR 0012).
- Los disparadores inmediatos no dependen de este valor: bloqueo de la sesión del SO, suspensión, pasar a segundo plano en Android y el botón "Bloquear".

## Consecuencias

- Con 15 minutos, la bóveda puede quedar desbloqueada en memoria hasta 15 minutos sin uso, frente a los 5 anteriores. Amplía la ventana del adversario 4 de `docs/THREAT_MODEL.md`. Es una elección explícita y la pantalla avisa al seleccionarlo.
- Un valor ilegible o desconocido en el almacenamiento vuelve a 5 minutos, nunca a "sin bloqueo".

## Alternativas consideradas

- **1, 5 y 30 minutos** o **30 s, 2 y 5 minutos:** ofrecidas al usuario, que eligió 1, 5 y 15.
- **Guardarlo dentro de la bóveda cifrada** (así se sincronizaría entre dispositivos): descartado, porque el valor se necesita antes del desbloqueo, y cada dispositivo puede querer uno distinto.
