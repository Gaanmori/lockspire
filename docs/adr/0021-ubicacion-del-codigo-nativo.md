# ADR 0021 — Ubicación del código nativo (Kotlin, C++)

- **Estado:** Aceptado
- **Fecha:** 2026-09-28
- **Origen:** revisión 2026-09-25, hallazgo A8. Decisión del usuario: documentar la excepción en vez de mover el código.
- **Precisa:** la convención de `CLAUDE.md` "Código nativo de autofill (Kotlin/Swift) vive en `features/autofill/infrastructure` de cada plataforma".

## Contexto

`CLAUDE.md` pide que el código nativo del autofill viva en `features/autofill/infrastructure`. En la práctica, todo el código nativo está donde lo exige cada sistema de build:

- **Android (Kotlin):** `app/android/app/src/main/kotlin/com/lockspire/lockspire/`. Ahí están el autofill (`LockspireAutofillService`, `LockspireCredentialProviderService` y `AutofillActivity`, ADR 0011 y 0020), el portapapeles seguro (`SecureClipboard`, S4), la protección de capturas (`ScreenSecurity`, S5) y `MainActivity`.
- **Windows (C++):** `app/windows/runner/`. Incluye el portapapeles seguro (`secure_clipboard.cpp`, S4) y los eventos de sesión del SO (ADR 0012).

Moverlos exigiría configurar `sourceSets` extra en Gradle y fuentes adicionales en CMake. Es posible, pero frágil: se rompe con las actualizaciones de las plantillas de Flutter y del Android Gradle Plugin, y desorienta a cualquiera que conozca la estructura estándar.

## Decisión

1. El código nativo se queda **en la ubicación estándar de cada plataforma**: `android/app/src/main/kotlin/...` para Android y `windows/runner/` para Windows (en el futuro, `linux/runner/` y `ios/Runner/`).
2. La separación que buscaba `CLAUDE.md` se mantiene por otras vías, que sí son verificables:
   - **Nativo delgado:** el código nativo nunca lee ni descifra la bóveda ni decide nada de negocio (ADR 0005, 0011 y 0020). Solo expone capacidades de la plataforma por `MethodChannel`.
   - **Cada canal tiene su adaptador Dart** en `features/<feature>/infrastructure`, detrás de un puerto del dominio. Por ejemplo `AndroidSecureClipboardAdapter` → `SecureClipboardPort`, y el autofill → `autofill_screen.dart`.
   - **Un archivo por responsabilidad** en el lado nativo (`SecureClipboard.kt`, `ScreenSecurity.kt`, `secure_clipboard.cpp`), con un comentario que remite al adaptador Dart y al ADR o hallazgo correspondiente.
3. `CLAUDE.md` se actualiza para reflejar esta regla.

## Consecuencias

- La estructura nativa es la que espera cualquiera que conozca Flutter, Android o Windows, y sobrevive a las actualizaciones de plantillas.
- La regla "el nativo no tiene lógica de negocio" es la que protege la arquitectura hexagonal. Se revisa en cada cambio al código nativo.
- Cuando el código nativo de una plataforma crezca mucho, se puede agrupar en subpaquetes (`com.lockspire.lockspire.autofill`, `…clipboard`) sin salir de la ubicación estándar.
