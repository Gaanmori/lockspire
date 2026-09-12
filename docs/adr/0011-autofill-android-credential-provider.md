# 0011 — Autofill nativo en Android (Credential Manager / `CredentialProviderService`)

- Estado: Aceptado
- Fecha: 2026-09-12
- Extiende: [ADR 0005](0005-protocolo-native-messaging.md) (mismo principio rector: "no duplicar el motor criptográfico en dos binarios/lenguajes distintos"). Reusa [ADR 0010](0010-desbloqueo-biometrico.md) (`BiometricAuthPort`) y el flujo de desbloqueo existente sin cambios.

## Contexto

Pedido confirmado por el usuario tras revisar SafeInCloud (ver `docs/STATE.md`, Backlog): autofill nativo en apps de Android, con Lockspire seleccionable como gestor de contraseñas del sistema — con prioridad sobre el autofill dentro del navegador móvil.

Investigado contra la documentación oficial de Android (no solo memoria/entrenamiento, mismo criterio ya usado para `local_auth`/`flutter_secure_storage` en ADR 0010): en 2026 coexisten dos sistemas independientes para esto — el `AutofillService` legado (Android 8+) y **Credential Manager / `CredentialProviderService`** (Android 14+, API 34). Google ya declara Credential Manager como el reemplazo recomendado de las APIs de autenticación legadas, y es el **único** de los dos que soporta passkeys (WebAuthn/FIDO2) — feature ya confirmada en el backlog de Lockspire. Construir sobre el `AutofillService` legado ahora habría significado rehacer la integración nativa entera al encarar passkeys después.

## Decisión

### Solo `CredentialProviderService` (Android 14+), sin fallback al `AutofillService` legado

Confirmado con el usuario. No baja el `minSdk` global de la app — el `compileSdk` ya está en 37 (fijado para `flutter_secure_storage`, ver `docs/STATE.md`), alcanza para compilar los símbolos de API 34. El servicio nuevo queda guardado con chequeos de `Build.VERSION.SDK_INT`; en un dispositivo con Android viejo el sistema operativo directamente nunca lo invoca — no rompe nada, solo no ofrece la feature ahí. Devices pre-14 quedan sin autofill nativo de Lockspire; se acepta como trade-off explícito a cambio de no mantener dos integraciones nativas distintas para la misma feature.

### Servicio nativo deliberadamente delgado, cero cripto nueva

Mismo principio rector que ADR 0005: el lado Kotlin (`LockspireCredentialProviderService`) **nunca lee ni desencripta la bóveda**. Implementa el modelo de dos fases de `CredentialProviderService`:

1. Android invoca `onBeginGetCredentialRequest()` (login) u `onBeginCreateCredentialRequest()` (guardar credencial nueva).
2. El servicio, sin tocar la bóveda, devuelve siempre una única entrada de autenticación genérica ("Lockspire") con un `PendingIntent` — mismo patrón que usan gestores de contraseñas reales (ej. Bitwarden) para "hace falta autenticar antes de revelar nada". No se pre-filtran credenciales en esta fase.
3. El `PendingIntent` lanza `AutofillActivity` (`extends FlutterFragmentActivity`, mismo patrón que `MainActivity` desde ADR 0010), con el nombre de paquete de la app solicitante como extra.
4. Todo lo sensible ocurre del lado Dart (`lib/features/autofill/`), reusando integralmente lo ya construido: si la bóveda está bloqueada, el flujo de desbloqueo normal (contraseña o biometría vía `BiometricAuthPort`, sin ningún camino nuevo); una vez desbloqueada, se filtra/lista según `matchEntriesForPackage()` (heurística pura, sin vinculación manual — ver más abajo) y el usuario elige o confirma guardar. La respuesta vuelve a la Activity nativa por un `MethodChannel`, que arma el resultado de la API de Android y cierra.

### Matching app↔entrada: heurística automática, sin UI de vinculación manual

Confirmado con el usuario (backlog lo dejaba anotado como "para cuando exista autofill real" — es ahora): en vez de una pantalla nueva para vincular entradas a apps explícitamente, se usa una función pura que compara el nombre de paquete contra título/URL de las entradas; si no hay match claro, se muestra la lista completa de todas formas. Más simple de construir, cubre el caso real desde el primer día. Vinculación manual queda como posible mejora futura, no descartada, solo no necesaria para esta pasada.

### Guardado: nunca silencioso

Mismo principio que `SAVE_CREDENTIAL` en ADR 0005 — confirmación explícita del usuario antes de crear una entrada nueva vía `addEntry()` (ya existente), nunca autoguardado.

## Alcance explícitamente fuera de esta pasada

- **Passkeys** (`TYPE_PUBLIC_KEY_CREDENTIAL`, `onBeginCreateCredentialRequest` para FIDO2) — implica generar y guardar pares de claves EC, cripto real nueva. Backlog separado, ya confirmado como feature futura, no se sobre-diseña acá.
- **`AutofillService` legado / Android <14** — descartado, ver arriba.
- **iOS (Credential Provider Extension)** — no es plataforma objetivo del proyecto todavía, mismo criterio que ADR 0010.
- **Windows desktop / "auto-type"** — explícitamente fuera de alcance por `CLAUDE.md` punto 4, no aplica a este ADR en absoluto.

## Alternativas consideradas

- **`AutofillService` legado (Android 8+) como base, con Credential Manager después:** descartado — habría significado dos integraciones nativas paralelas para la misma feature, y rehacer la primera al llegar a passkeys, que solo Credential Manager soporta.
- **Vinculación manual app↔entrada desde el día uno:** descartado por ahora a favor de la heurística automática — es una feature de UI aparte que puede sumarse después sin romper el diseño de esta pasada (la heurística seguiría funcionando como fallback).
- **Que el servicio Kotlin decida qué credenciales mostrar antes de autenticar** (pre-filtrar en la fase de query): descartado — implicaría que el proceso nativo tenga que leer/desencriptar la bóveda para saber qué mostrar, exactamente lo que este ADR evita.
