# ADR 0019 — Protección contra rollback de la bóveda sincronizada

- **Estado:** Aceptado
- **Fecha:** 2026-09-27
- **Origen:** revisión de seguridad 2026-09-25, hallazgo S2 (`docs/reviews/2026-09-25-revision-arquitectura-solid-seguridad.md`). Extiende ADR 0004 (formato) y cierra el riesgo señalado en ADR 0018.

## Contexto

El AEAD (ADR 0002 y 0004) garantiza que un archivo de bóveda es **auténtico**, pero no que sea **actual**. Quien controle la nube del usuario (adversarios 1 y 3 del threat model) puede guardar una copia vieja y volver a subirla más tarde. Hoy la sync la trata como un cambio remoto legítimo:

- Si el dispositivo no tenía cambios locales, la descarga tal cual. Vuelven contraseñas viejas y reaparecen entradas borradas.
- Si tenía cambios, el merge de 3 vías (ADR 0006) interpreta como "borradas en el remoto" las entradas que la copia vieja no tiene.
- Con ADR 0018, además, se puede revertir un cambio de contraseña maestra subiendo un archivo con el salt anterior.

## Decisión

### 1. Número de revisión en el header (formato v2)

- `VaultHeader` gana un campo `revision`: un entero que **solo sube**. Cada archivo nuevo tiene una revisión mayor que la del archivo del que parte:
  - Al guardar: la revisión del archivo en disco + 1, leída en el mismo control de concurrencia de `SaveVaultUseCase`, así que nunca depende de una sesión desactualizada.
  - Al fusionar (sync o adopción de contraseña): `max(local, remoto) + 1`.
  - Al cambiar la contraseña: la del archivo sincronizado + 1.
- Va en el header, que viaja en claro pero **autenticado como AAD**. No se puede cambiar sin romper el descifrado, y la sync puede compararlo sin descifrar.
- Los archivos con revisión usan `format_version = 2` y `format_min_reader_version = 2`. Un lector v1 los rechaza con el error claro de "formato más nuevo", en vez de fallar la autenticación.
- **Compatibilidad:** los archivos v1 existentes se leen con revisión 0, y su AAD no cambia porque el campo solo se serializa en v2. El primer guardado con esta versión los pasa a v2 con revisión 1.

### 2. Regla de rechazo en la sync

La referencia es la revisión del **ancestro**: el último archivo que este dispositivo sincronizó con éxito (ADR 0006), que vive en disco local. Solo se comprueba cuando el remoto cambió y se va a usar (descarga, merge o adopción de contraseña):

- Si la referencia es mayor que 0 y la revisión remota es **menor o igual** a ella, se rechaza con `RemoteVaultRejection.rollback` y no se toca nada local.
- La igualdad también se rechaza: el remoto cambió respecto del ancestro, y un cambio legítimo siempre sube la revisión.

No se comprueba en estos casos:
- No hay ancestro, por ejemplo al restaurar en un dispositivo nuevo o en instalaciones de antes de la sync. El primer contacto se confía (TOFU).
- El ancestro es un archivo v1 (revisión 0), porque no hay contra qué comparar. En cuanto se sincroniza un archivo v2, cualquier archivo v1 que vuelva a aparecer queda por debajo y se rechaza.

### 3. Recuperación

Si el rechazo fue legítimo (el usuario restauró a propósito una copia vieja en la nube), Sincronización ofrece **"Subir la versión de este dispositivo"**. Reemplaza el remoto por la bóveda local, que es la más nueva que el dispositivo conoce. No se pierde nada que este dispositivo no tenga ya, porque la copia rechazada es más vieja que lo que ya se sincronizó.

## Consecuencias

- **Un rollback ya no puede revertir cambios que este dispositivo ya sincronizó**, incluido un cambio de contraseña maestra. Esto cierra la consecuencia pendiente de ADR 0018.
- **Todos los dispositivos deben actualizarse:** una versión vieja de la app no abre archivos v2 y avisa que el formato es más nuevo. Una versión vieja que llegara a subir un archivo v1 sería rechazada por las nuevas como rollback.
- **Límites que quedan documentados:**
  - Un dispositivo sin ancestro confía en lo primero que baja.
  - Si la nube reproduce un archivo con revisión mayor que la del ancestro pero de una rama que después se descartó (algo que produjo otro dispositivo propio), el merge lo trata como un cambio normal. No revierte nada que este dispositivo ya haya visto, solo puede no incluir cambios que tampoco vio.
  - El número de revisión es visible en la nube. Revela cuántas veces se guardó la bóveda, lo mismo que ya se puede deducir observando las subidas.
