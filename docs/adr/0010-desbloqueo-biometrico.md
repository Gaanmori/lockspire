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

### Un solo puerto, mismo mecanismo de gating en las dos plataformas

`BiometricAuthPort` (`vault/domain/ports/biometric_auth_port.dart`) es agnóstico de plataforma — `checkAvailability`, `hasStoredKey`, `storeKey`, `readKey` (dispara el prompt del SO, `null` si se cancela/falla, nunca lanza para ese caso), `deleteKey`, y el flag de onboarding ya mostrado. El dominio/aplicación nunca sabe qué hay debajo.

**Android y Windows usan el mismo patrón** (`android_biometric_auth_adapter.dart`/`windows_biometric_auth_adapter.dart`, casi idénticos): `local_auth` dispara el prompt real del sistema (`BiometricPrompt` en Android, Windows Hello en Windows — confirmado leyendo el código fuente C++/WinRT de `local_auth_windows`: usa `IUserConsentVerifierInterop::RequestVerificationForWindowAsync`, el patrón correcto para apps de escritorio, no `UserConsentVerifier.RequestVerificationAsync` que es solo para UWP) y, solo si el usuario lo pasa, se lee la clave de un `FlutterSecureStorage` **plano** (sin opciones biométricas en ninguna de las dos plataformas).

**Diseño original descartado tras verificación manual real, no solo en el papel:** la primera versión usaba `AndroidOptions.biometric(enforceBiometrics: true)` de `flutter_secure_storage` en Android — gating a nivel de Android Keystore, hardware/TEE-backed en el papel, más fuerte que un chequeo de `local_auth`. Se abandonó al encontrar un bug real probando en dispositivo: **el plugin cachea el cifrado de datos ya desenvuelto a nivel del objeto Java de la instancia** (campo `storageCipher` en `FlutterSecureStorage.java`, confirmado leyendo el código fuente) — una vez pasada la biometría una vez dentro del proceso de la app, todas las lecturas siguientes la reusan sin volver a pedirla, sin importar cuántas veces la app llame a `lock()` (eso solo cambia estado de Dart, nunca toca el caché nativo del plugin). Síntoma real observado: tras activar la huella una vez, "Bloquear" + "Usar huella" entraba directo, sin pedir huella de nuevo — exactamente lo opuesto de lo que se buscaba. `local_auth.authenticate()` no tiene ese problema — cada llamada dispara un desafío nuevo de verdad, sin caché de por medio.

**Se evaluó `biometric_storage`** (usado por AuthPass, otro password manager en Flutter) como alternativa unificada para las dos plataformas — descartado: su implementación de Windows (leída en el código fuente) es solo Credential Manager, con `canAuthenticate()` devolviendo siempre "hardware no disponible" — no dispara ningún desafío biométrico real.

### Alcance: Android + Windows únicamente

No son plataformas objetivo de este proyecto por ahora iOS/macOS/Linux/web — `UnavailableBiometricAuthAdapter` cubre esos casos sin crashear (`checkAvailability()` siempre `unavailable`), sin implementar nada real ahí.

## Trade-off aceptado, explícito a propósito: el gating es a nivel de app, no del SO

**En las dos plataformas el gating es a nivel de app** (el adaptador exige pasar la biometría/Windows Hello *antes* de leer, no el sistema operativo el que lo exige al liberar el secreto) — no hardware-enforced como podría serlo en Android con el Keystore (ver el diseño descartado arriba, y por qué no se pudo usar tal cual). Un atacante con privilegios de proceso suficientes en una sesión ya iniciada podría, en teoría, leer el `FlutterSecureStorage` plano sin pasar por `local_auth` si logra invocar el código de lectura directamente — ese nivel de compromiso ya cae dentro del actor "malware/proceso local con privilegios de usuario" que `docs/THREAT_MODEL.md` ya trata como parcialmente fuera de control de la app (ver ese documento, actualizado junto con este ADR). Se documenta como limitación conocida y aceptada, no se oculta — la alternativa hardware-bound en Android resultó, en la práctica, no ofrecer un "re-pedir siempre" confiable, que era el requisito real pedido por el usuario; un gating a nivel de app pero consistente y predecible en las dos plataformas se prefirió sobre uno "más fuerte en el papel" pero que en los hechos no volvía a pedir la verificación.

## Alternativas consideradas

- **Gating a nivel de Android Keystore (`AndroidOptions.biometric`) en vez de `local_auth` en Android:** era el diseño original — descartado tras el bug real de caché descrito arriba, no por preferencia de antemano.
- **`AndroidBiometricType.strongBiometricOnly`** (rechazar PIN/patrón, exigir solo biometría real) en vez del default `biometricOrDeviceCredential`: habría quedado sin efecto igual (era una opción del diseño descartado), pero además el PIN/patrón del sistema ya es un factor "algo que sabés" gateado por el propio lock screen del SO — exigir *además* biometría específicamente no suma seguridad real y sí puede dejar afuera a quien no tiene huella enrolada.
- **Guardar la contraseña maestra en vez de la clave ya derivada:** descartado de plano — expondría la contraseña en texto recuperable en vez de un material derivado de un solo uso para esta bóveda, contradice el modelo de amenaza de raíz.
