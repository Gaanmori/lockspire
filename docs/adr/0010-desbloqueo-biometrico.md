# 0010 — Desbloqueo biométrico (huella en Android, Windows Hello en escritorio)

- Estado: Aceptado
- Fecha: 2026-09-11
- Extiende: [ADR 0002](0002-motor-criptografico.md) (ya anticipaba esto como mitigación de UX, sin diseño concreto — "si el desbloqueo tarda en un dispositivo más limitado, se resuelve con UX: indicador de progreso, desbloqueo biométrico tras el primer login"). No modifica [ADR 0007](0007-paralelismo-argon2id-libsodium.md) — los parámetros de Argon2id no cambian.

## Contexto

Pedido explícito del usuario: poder desbloquear la bóveda con la huella en Android y con Windows Hello en la app de escritorio, en vez de reescribir la contraseña maestra (y esperar los ~3.5s de Argon2id, ver el benchmark de Fase 2) en cada desbloqueo.

`UnlockVaultUseCase.reloadWithKey({required Uint8List key})` ya existía (Fase 5/7, para recuperación tras conflicto de escritura y recarga post-sync) — desbloquea con una clave ya derivada, sin Argon2id ni contraseña. Es la pieza que este ADR reusa: el desbloqueo biométrico nunca deriva nada nuevo, solo cachea la clave que una sesión real con contraseña ya derivó, y la recupera después detrás de la biometría/PIN del sistema operativo.

## Decisión

### Modelo: la contraseña maestra sigue siendo la única forma de *derivar* la clave

La biometría nunca bootstrapea una bóveda nueva ni reemplaza Argon2id — solo cachea, tras un desbloqueo real por contraseña, la clave ya derivada, detrás de la biometría/PIN del sistema operativo. Activar el desbloqueo biométrico es **opt-in explícito**, nunca automático: se ofrece una sola vez (aviso único, descartable, no se vuelve a mostrar) tras el primer desbloqueo/creación exitosos si hay biometría disponible, y se puede activar/desactivar en cualquier momento desde una pantalla "Seguridad".

### Un solo puerto, gating distinto por plataforma

`BiometricAuthPort` (`vault/domain/ports/biometric_auth_port.dart`) es agnóstico de plataforma — `checkAvailability`, `hasStoredKey`, `storeKey`, `readKey` (dispara el prompt del SO, `null` si se cancela/falla, nunca lanza para ese caso), `deleteKey`, y el flag de onboarding ya mostrado. El dominio/aplicación nunca sabe qué hay debajo.

**Android** (`android_biometric_auth_adapter.dart`): usa el gating biométrico nativo de `flutter_secure_storage` v11 (`AndroidOptions.biometric(enforceBiometrics: true)`) — la clave queda envuelta por una clave de Android Keystore con autenticación de usuario requerida, **hardware/TEE-backed**: el propio Keystore rechaza liberar la clave sin pasar la biometría/PIN, no es un chequeo de la app antes de leer texto plano. El `read()`/`write()` del paquete ya muestra el prompt del sistema — no hace falta `local_auth` para esto en Android.

**Windows** (`windows_biometric_auth_adapter.dart`): no existe un equivalente al Keystore accesible desde Flutter — `flutter_secure_storage` en Windows es Credential Manager/DPAPI atado a la sesión de usuario, sin desafío biométrico en vivo. Se usa `local_auth` (paquete oficial del equipo de Flutter, `local_auth_windows`) para disparar un prompt real de Windows Hello — confirmado leyendo su código fuente C++/WinRT: usa `IUserConsentVerifierInterop::RequestVerificationForWindowAsync`, el patrón correcto para apps de escritorio (no `UserConsentVerifier.RequestVerificationAsync`, que es solo para UWP) — y solo si el usuario lo pasa, se lee la clave de un `FlutterSecureStorage` plano.

**Se evaluó `biometric_storage`** (usado por AuthPass, otro password manager en Flutter) como alternativa unificada para las dos plataformas — descartado: su implementación de Windows (leída en el código fuente) es solo Credential Manager, con `canAuthenticate()` devolviendo siempre "hardware no disponible" — no dispara ningún desafío biométrico real, no resuelve nada que `flutter_secure_storage` plano ya no resuelva.

### Alcance: Android + Windows únicamente

No son plataformas objetivo de este proyecto por ahora iOS/macOS/Linux/web — `UnavailableBiometricAuthAdapter` cubre esos casos sin crashear (`checkAvailability()` siempre `unavailable`), sin implementar nada real ahí.

## Trade-off aceptado, explícito a propósito: asimetría de gating entre plataformas

**En Android el gating es hardware-enforced (Keystore/TEE); en Windows es un chequeo a nivel de app** (el adaptador exige pasar Windows Hello *antes* de leer, no el sistema operativo el que lo exige al liberar el secreto). Un atacante con privilegios de proceso suficientes en una sesión de Windows ya iniciada podría, en teoría, leer el `FlutterSecureStorage` plano sin pasar por `local_auth` si logra invocar el código de lectura directamente — ese nivel de compromiso ya cae dentro del actor "malware/proceso local con privilegios de usuario" que `docs/THREAT_MODEL.md` ya trata como parcialmente fuera de control de la app (ver ese documento, actualizado junto con este ADR). No se resuelve con este ADR porque Windows no expone (por ahora) un primitivo equivalente al Android Keystore accesible desde Flutter — se documenta como limitación conocida, no se oculta.

## Alternativas consideradas

- **`local_auth` también en Android** (en vez de delegar en `flutter_secure_storage`): descartado — sería estrictamente más débil que el gating a nivel de Keystore que `flutter_secure_storage` ya ofrece (un `authenticate()` de `local_auth` por sí solo es solo un booleano, no ata criptográficamente el secreto a la verificación).
- **`AndroidBiometricType.strongBiometricOnly`** (rechazar PIN/patrón, exigir solo biometría real) en vez del default `biometricOrDeviceCredential`: descartado — el PIN/patrón del sistema ya es un factor "algo que sabés" gateado por el propio lock screen del SO, exigir *además* biometría específicamente no suma seguridad real y sí puede dejar afuera a quien no tiene huella enrolada.
- **Guardar la contraseña maestra en vez de la clave ya derivada:** descartado de plano — expondría la contraseña en texto recuperable en vez de un material derivado de un solo uso para esta bóveda, contradice el modelo de amenaza de raíz.
