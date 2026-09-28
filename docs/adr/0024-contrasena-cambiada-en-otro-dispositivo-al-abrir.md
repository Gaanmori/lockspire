# ADR 0024 — Si la contraseña se cambió en otro dispositivo, se pide la nueva al abrir

- **Estado:** Aceptado
- **Fecha:** 2026-09-28
- **Complementa:** ADR 0018 (cambio de contraseña maestra), ADR 0010 (biometría), ADR 0017 (pedir la contraseña cada N días)
- **Origen:** el usuario pidió que, si ya se sabe que la contraseña cambió en otro dispositivo, la app pida la nueva al abrir. En ese caso debe ser obligatorio escribirla, sin huella ni Windows Hello.

## Contexto

Con ADR 0018, un dispositivo se entera del cambio de contraseña solo al sincronizar, ya desbloqueado con la contraseña **vieja** (normalmente con la huella). Entonces muestra un aviso con un botón para ingresar la nueva.

Eso tiene dos problemas:

- Hasta que el usuario entra a sincronizar, la biometría sigue abriendo la bóveda con la clave vieja, como si nada hubiera pasado.
- La contraseña que el usuario acaba de elegir no se le pide nunca en este dispositivo.

## Decisión

1. **Se recuerda.** Cuando una sync detecta `passwordChanged`, se guarda una marca en el almacenamiento seguro (`SyncStatePort.passwordChangedElsewhere`). Una sync exitosa o la adopción de la contraseña nueva la borran.
2. **Al abrir, sin biometría.**
   - Si la marca está, la pantalla de desbloqueo pide la **contraseña maestra nueva** y no ofrece la huella ni Windows Hello.
   - La regla se aplica en el controller (`unlockWithBiometrics` no hace nada), no solo ocultando el botón.
3. **También sin sync previa.** Con la pantalla de bloqueo abierta, se mira la nube en segundo plano. Solo se lee el header, sin descifrar.
   - Si la copia es **más nueva** que la última sincronizada (ADR 0019) y tiene otra derivación de clave, se anota y la pantalla pasa al modo "contraseña nueva".
   - Así la huella de cada día no espera a la red.
   - Una copia vieja con otro salt es rollback, no un cambio de contraseña.
4. **Entrar con la nueva.**
   - La contraseña nueva se verifica con AEAD contra la copia de la nube antes de escribir nada, reusando `AdoptRemoteMasterPasswordUseCase`.
   - Si este dispositivo tiene cambios **sin sincronizar**, están cifrados con la contraseña anterior. Para conservarlos se pide también la anterior (`PreviousPasswordRequiredException`).
   - Tras adoptar, la clave para biometría se renueva (como en ADR 0018) y la huella vuelve a funcionar.
5. **Salida.** "No tengo la contraseña nueva" permite entrar con la anterior. Sigue sin biometría y el aviso continúa hasta que se adopte la nueva.
   - Existe porque una nube manipulada o un cambio que el usuario ya no recuerda no pueden dejarlo fuera de sus datos locales.
6. **Arquitectura.** `vault` define `PasswordChangedElsewherePort` (en `application/`, porque devuelve `UnlockedVaultResult`) con un valor por defecto sin sync. `sync` lo implementa (`SyncPasswordChangedElsewhere`) y la app los conecta en `lib/app_composition.dart`, igual que la réplica de ADR 0018.

## Consecuencias

- Tras un cambio de contraseña, cada dispositivo la pide una vez en cuanto lo sabe, y ninguno sigue abriendo con la clave vieja por biometría.
- Una nube manipulada puede forzar que se pida la contraseña en vez de la huella. Es más seguro, no menos, y la salida del punto 5 evita el bloqueo total.
- Abrir la pantalla de bloqueo hace una descarga de la nube en segundo plano. Sin red no pasa nada.
