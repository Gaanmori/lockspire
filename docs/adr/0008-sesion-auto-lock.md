# 0008 — Sesión: auto-lock por inactividad y al pasar a segundo plano

- Estado: Aceptado — disparador 2 ("app en segundo plano") reemplazado **solo en escritorio** por [ADR 0012](0012-escritorio-bandeja-y-bloqueo.md); el timeout fijo de 5 minutos, reemplazado por [ADR 0016](0016-tiempo-de-bloqueo-configurable.md) (1, 5 o 15 minutos, 5 por defecto)
- Fecha: 2026-09-09

## Contexto

[Threat Model](../THREAT_MODEL.md), adversario 4 (malware o proceso local con privilegios de usuario mientras la bóveda está desbloqueada), quedó explícitamente sin mitigar: "minimizar el tiempo que la clave derivada permanece en memoria y aplicar auto-lock por inactividad (a especificar en un ADR de sesión/auto-lock cuando se implemente esa feature)". Esta es esa feature.

`VaultSessionController` (`lib/features/vault/presentation/vault_session_controller.dart`) ya existe con un método `lock()` — auto-lock solo necesita decidir *cuándo* llamarlo automáticamente.

## Decisión

### Dos disparadores

1. **Inactividad** — sin interacción del usuario durante el timeout configurado → bloquear. Es lo que pide literalmente el Threat Model.
2. **App en segundo plano** (backgrounding móvil / minimizar en desktop) → bloquear inmediatamente. No está pedido explícitamente por el texto del Threat Model, pero es el comportamiento estándar de cualquier gestor de contraseñas serio (Bitwarden, 1Password) y es barato de implementar (`AppLifecycleState` de Flutter) — omitirlo dejaría un gap real: un atacante con acceso físico momentáneo al dispositivo desbloqueado, o el propio SO mostrando el contenido de la app en el selector de apps recientes, son escenarios que la sola inactividad no cubre.

Específicamente se bloquea en `AppLifecycleState.paused` y `.hidden`, pero **no** en `.inactive` — este último dispara también en interrupciones breves (una notificación, el selector de apps pasando por encima un instante) que no representan realmente "el usuario dejó la app".

### Timeout: 5 minutos, fijo

No configurable por el usuario en esta fase — una pantalla de ajustes es una feature aparte. 5 minutos es un valor intermedio razonable entre seguridad y fricción de re-desbloquear (que además cuesta ~3.5s de Argon2id, medido en `docs/STATE.md`).

### Detección de actividad: no solo taps

Un solo `onPointerDown` no basta — si el usuario está escribiendo en un campo largo o haciendo scroll sin volver a tocar la pantalla, eso también debe contar como actividad. Se cubren tres vías: punteros (tap/click), scroll wheel/trackpad (`onPointerSignal`), y teclado (`HardwareKeyboard`). Ver implementación en `ActivityAndLifecycleWatcher`.

### Qué significa "bloquear" en términos de memoria — limitación conocida

`lock()` limpia la referencia al `Vault` desencriptado en el estado del controller y deja que el recolector de basura de Dart lo recoja — **no hay borrado explícito (zeroing) de esa memoria**. El dominio actual guarda el contenido de la bóveda como objetos Dart planos (`Vault`, `VaultEntry`), no como `SecureKey` de libsodium; `SecureKey` solo se usa dentro de `SodiumCryptoAdapter` para las claves, durante la propia operación de cifrado/descifrado, no para el contenido ya desencriptado que vive en el estado de la UI. Envolver todo el contenido de la bóveda en memoria protegida sería un rediseño mayor del dominio, fuera de alcance de esta fase — se acepta la limitación y se documenta explícitamente en vez de fingir una garantía que no existe.

## Alternativas consideradas

- **Timeout configurable desde el arranque:** descartado por ahora — añade una pantalla de ajustes completa para una sola opción; se revisita cuando exista esa feature.
- **Bloquear también en `AppLifecycleState.inactive`:** descartado — demasiado agresivo, bloquearía la bóveda por interrupciones del sistema que no son realmente abandonar la app.
