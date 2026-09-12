# 0011 — Autofill nativo en Android (Credential Manager + `AutofillService` legado)

- Estado: Aceptado
- Fecha: 2026-09-12
- Extiende: [ADR 0005](0005-protocolo-native-messaging.md) (mismo principio rector: "no duplicar el motor criptográfico en dos binarios/lenguajes distintos"). Reusa [ADR 0010](0010-desbloqueo-biometrico.md) (`BiometricAuthPort`) y el flujo de desbloqueo existente sin cambios.

## Contexto

Pedido confirmado por el usuario tras revisar SafeInCloud (ver `docs/STATE.md`, Backlog): autofill nativo en apps de Android, con Lockspire seleccionable como gestor de contraseñas del sistema — con prioridad sobre el autofill dentro del navegador móvil.

Investigado contra la documentación oficial de Android (no solo memoria/entrenamiento, mismo criterio ya usado para `local_auth`/`flutter_secure_storage` en ADR 0010): en 2026 coexisten dos sistemas independientes para esto — el `AutofillService` legado (Android 8+) y **Credential Manager / `CredentialProviderService`** (Android 14+, API 34). Google ya declara Credential Manager como el reemplazo recomendado de las APIs de autenticación legadas, y es el **único** de los dos que soporta passkeys (WebAuthn/FIDO2) — feature ya confirmada en el backlog de Lockspire. Construir sobre el `AutofillService` legado ahora habría significado rehacer la integración nativa entera al encarar passkeys después.

## Decisión

### `CredentialProviderService` (Android 14+) como camino principal — y `AutofillService` legado también, agregado en la misma pasada tras encontrar un hueco real

El diseño original de este ADR era "solo Credential Manager, sin el `AutofillService` legado" — confirmado con el usuario en la decisión inicial. **Corregido en la misma pasada de verificación manual**, mismo criterio ya establecido en ADR 0010: se encontró, con evidencia real (no solo teoría), que Credential Manager **no tiene soporte para campos dentro de un `WebView`** en esta versión de Android — confirmado probando el login de Crunchyroll (que ocurre en un `WebView`, `SsoWebViewActivity`) contra SafeInCloud, que sí pudo autocompletar ahí porque usa el `AutofillService` legado. El log del sistema (`adb shell dumpsys`) confirmó que ni siquiera se llegaba a consultar a `LockspireCredentialProviderService` para ese caso — no era un bug de filtrado nuestro, es que Credential Manager directamente no intenta bridging de WebViews todavía en esta versión de Android.

Investigando cómo lo resuelven gestores de contraseñas reales (código fuente de Bitwarden vía GitHub, mismo criterio de "leer la fuente real" ya establecido): **todos** implementan más de un mecanismo — Bitwarden tiene Credential Manager + `AutofillService` legado + un `AccessibilityService` de respaldo (para WebViews/campos no estándar que ninguno de los dos anteriores alcanza); KeePassDX usa un teclado propio en vez de Accessibility. Confirma que esto no es una limitación de Lockspire, es una limitación conocida y aceptada en toda la industria de Android.

**Decisión final, confirmada con el usuario:** agregar `LockspireAutofillService` (el `AutofillService` legado) además de Credential Manager, no en su reemplazo — los dos conviven, cada uno cubre lo que el otro no. El `AccessibilityService` de respaldo (lo que usa Bitwarden para el hueco de WebView que ni el legado cubre en todos los casos) queda **explícitamente fuera de esta pasada**: existe una vulnerabilidad real y documentada (AutoSpill) específica de ese mecanismo, donde la credencial puede filtrarse al campo nativo equivocado de la app que aloja el WebView por perder la verificación de origen que sí da el Autofill Framework — es una decisión de seguridad real que amerita evaluarse con la cabeza despierta en otra sesión, no agregarse por default solo porque otros lo hacen.

No baja el `minSdk` global de la app para ninguno de los dos servicios — el `compileSdk` ya está en 37 (fijado para `flutter_secure_storage`, ver `docs/STATE.md`), alcanza para compilar los símbolos de API 34. `LockspireCredentialProviderService` queda guardado con chequeos de `Build.VERSION.SDK_INT`; en un dispositivo con Android viejo el sistema operativo directamente nunca lo invoca. `LockspireAutofillService` no necesita ese guard — es API 26+, y el propio framework nunca lo invoca en un dispositivo que no lo soporte.

### Servicios nativos deliberadamente delgados, cero cripto nueva

Mismo principio rector que ADR 0005: ni `LockspireCredentialProviderService` ni `LockspireAutofillService` **leen ni desencriptan la bóveda nunca**. Los dos siguen el mismo patrón de dos fases:

1. Android invoca `onBeginGetCredentialRequest()`/`onFillRequest()` (login) u `onBeginCreateCredentialRequest()`/`onSaveRequest()` (guardar credencial nueva).
2. El servicio, sin tocar la bóveda, arma una única sugerencia genérica ("Lockspire") gateada por autenticación — mismo patrón que usan gestores de contraseñas reales (ej. Bitwarden) para "hace falta autenticar antes de revelar nada". No se pre-filtran credenciales en esta fase. En el `AutofillService` legado esto implica además detectar qué campos de la pantalla son rellenables (`findAutofillFields()`, heurística en tres capas: `autofillHints`, atributos HTML del WebView, `inputType` como último recurso — necesaria justamente porque las apps reales no siempre son consistentes, ver los bugs encontrados más abajo).
3. Un `PendingIntent` (o, para el guardado del `AutofillService` legado, un `startActivity` directo desde el servicio) lanza `AutofillActivity` (`extends FlutterFragmentActivity`, mismo patrón que `MainActivity` desde ADR 0010), con los datos necesarios como extras — el paquete solicitante y, para el `AutofillService` legado en modo "get", los `AutofillId` de los campos detectados.
4. Todo lo sensible ocurre del lado Dart (`lib/features/autofill/`), reusando integralmente lo ya construido: si la bóveda está bloqueada, el flujo de desbloqueo normal (contraseña o biometría vía `BiometricAuthPort`, sin ningún camino nuevo); una vez desbloqueada, se filtra/lista según `matchEntriesForPackage()` (heurística pura, con un buscador por título siempre visible como respaldo — ver Backlog) y el usuario elige o confirma guardar. La respuesta vuelve a la Activity nativa por un `MethodChannel`, que arma el resultado según cuál de los dos orígenes la lanzó (Credential Manager vía `PendingIntentHandler`, o el `AutofillService` legado vía `AutofillManager.EXTRA_AUTHENTICATION_RESULT` con un `Dataset` real) y cierra.

### Matching app↔entrada: heurística automática, sin UI de vinculación manual

Confirmado con el usuario (backlog lo dejaba anotado como "para cuando exista autofill real" — es ahora): en vez de una pantalla nueva para vincular entradas a apps explícitamente, se usa una función pura que compara el nombre de paquete contra título/URL de las entradas; si no hay match claro, se muestra la lista completa de todas formas. Más simple de construir, cubre el caso real desde el primer día. Vinculación manual queda como posible mejora futura, no descartada, solo no necesaria para esta pasada.

### Guardado: nunca silencioso

Mismo principio que `SAVE_CREDENTIAL` en ADR 0005 — confirmación explícita del usuario antes de crear una entrada nueva vía `addEntry()` (ya existente), nunca autoguardado.

## Bugs reales encontrados y corregidos en la verificación manual (misma pasada)

- **Lockspire aparecía en flujos ajenos (ej. "Iniciar sesión con Google" de AliExpress):** `onBeginGetCredentialRequest` respondía a cualquier pedido de credencial sin fijarse el tipo. Corregido: solo responde si el pedido incluye una `BeginGetPasswordOption` real.
- **Crash real en `LockspireAutofillService.onFillRequest`** (`IllegalArgumentException: No such package <paquete de la app solicitante>`, confirmado con SoundHound): una variable local llamada `packageName` (el paquete de la app que pide el autofill) tapaba por *shadowing* al `packageName` del propio `Context` de Lockspire, que es el que necesita `RemoteViews` para construirse. Corregido renombrando la variable local a `requestingPackage`.
- **Usuario y contraseña invertidos al autocompletar** (confirmado con SoundHound): dos causas combinadas en `findAutofillFields()` — (1) los valores `TYPE_TEXT_VARIATION_*` de `InputType` no son banderas independientes, son valores excluyentes de un sub-campo de 4 bits (`TYPE_MASK_VARIATION`); compararlos con "AND distinto de cero" en vez de aislar el sub-campo e igualar exacto daba falsos positivos cruzados entre el campo de contraseña y el de usuario/email; (2) el campo de contraseña real de SoundHound usa el hint no estándar `"passwordAuto"` en vez del `"password"` oficial de Android, así que ni siquiera se reconocía por hint y dependía del `inputType` ya roto. Corregido: comparación exacta contra el sub-campo de variación, y matching de hints por substring (`contains("password")`) en vez de igualdad exacta.

## Alcance explícitamente fuera de esta pasada

- **Passkeys** (`TYPE_PUBLIC_KEY_CREDENTIAL`, `onBeginCreateCredentialRequest` para FIDO2) — implica generar y guardar pares de claves EC, cripto real nueva. Backlog separado, ya confirmado como feature futura, no se sobre-diseña acá.
- **`AccessibilityService` de respaldo** (para el hueco de WebView que ni Credential Manager ni el `AutofillService` legado cubren en todos los casos) — descartado por ahora por el riesgo de seguridad real (AutoSpill), ver arriba. No descartado para siempre, es una decisión a revisar con más calma.
- **Vinculación manual/automática app↔entrada** (que una entrada "recuerde" a qué apps pertenece después de elegirla una vez, como hace SafeInCloud) — pedido explícito del usuario tras verificar el flujo completo, queda anotado como el próximo paso concreto (ver `docs/STATE.md`), no implementado en esta pasada.
- **iOS (Credential Provider Extension)** — no es plataforma objetivo del proyecto todavía, mismo criterio que ADR 0010.
- **Windows desktop / "auto-type"** — explícitamente fuera de alcance por `CLAUDE.md` punto 4, no aplica a este ADR en absoluto.

## Alternativas consideradas

- **Solo Credential Manager, sin el `AutofillService` legado:** era la decisión original de este ADR — revertida en la misma pasada al encontrar el hueco real de WebView, ver arriba.
- **Agregar también un `AccessibilityService` de respaldo, como Bitwarden:** evaluado y descartado por ahora — el riesgo de seguridad (AutoSpill) amerita una decisión aparte, no agregarse solo por paridad con otros gestores.
- **Vinculación manual app↔entrada desde el día uno:** descartado por ahora a favor de la heurística automática — es una feature de UI aparte que puede sumarse después sin romper el diseño de esta pasada (la heurística seguiría funcionando como fallback). El usuario pidió esto mismo después de usar la feature real, queda para la próxima sesión.
- **Que el servicio Kotlin decida qué credenciales mostrar antes de autenticar** (pre-filtrar en la fase de query): descartado — implicaría que el proceso nativo tenga que leer/desencriptar la bóveda para saber qué mostrar, exactamente lo que este ADR evita.
