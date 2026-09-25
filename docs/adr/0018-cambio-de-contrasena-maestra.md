# ADR 0018 — Cambio de contraseña maestra y fortaleza mínima

- **Estado:** Aceptado
- **Fecha:** 2026-09-25
- **Origen:** revisión de seguridad 2026-09-25, hallazgo S8 (`docs/reviews/2026-09-25-revision-arquitectura-solid-seguridad.md`).

## Contexto

Hasta ahora no había forma de cambiar la contraseña maestra, así que no se podía rotar ante una sospecha de filtración. Además, crear una bóveda solo exigía 8 caracteres, y "12345678" era válida.

La contraseña determina la clave vía Argon2id con el **salt del header** (ADR 0002 y 0004). Cambiarla implica un salt nuevo, una clave nueva y volver a cifrar. Eso choca con la sync:

- Desde S1, la sync solo acepta un archivo remoto que se descifre con la clave de la sesión. Un dispositivo que siga con la contraseña vieja rechazaría para siempre la bóveda recifrada.
- El ancestro del merge de 3 vías (ADR 0006) queda cifrado con la clave vieja.

## Decisión

### 1. Política de contraseña nueva

Se aplica al **crear** la bóveda y al **cambiar** la contraseña. Nunca se aplica al desbloquear: las bóvedas existentes siguen abriéndose. La contraseña tiene que cumplir:

- Al menos **12 caracteres**.
- Al menos **6 caracteres distintos**, para rechazar cosas como `aaaaaaaaaaaa`.
- Al menos **50 bits** según `estimatePasswordStrength`.

### 2. Cambio en el dispositivo que lo inicia (`ChangeMasterPasswordUseCase`)

1. Se pide la contraseña actual y se verifica derivando y descifrando el archivo local. Aunque la bóveda esté desbloqueada, se exige, para que alguien frente a una sesión abierta no pueda apropiarse de la bóveda.
2. **Si hay sync configurada, se sincroniza primero** con la clave actual. Si falla (sin conexión, remoto rechazado…), **no se cambia nada** y se avisa. Así local, remoto y ancestro quedan iguales antes de recifrar, y no hay cambios pendientes cifrados con la clave vieja.
3. Se genera un salt nuevo y se deriva la clave nueva con los parámetros por defecto vigentes. De paso se actualizan los parámetros de Argon2id si eran antiguos. `vault_id` y `created_at` se conservan.
4. **Primero se publica el archivo recifrado en la nube** y se marca como sincronizado, lo que convierte al archivo nuevo en el ancestro. **Después** se escribe localmente, de forma atómica.
   - Si falla la subida, no se tocó nada local.
   - Si falla la escritura local después de subir, este dispositivo queda como cualquier otro con la contraseña vieja y se recupera con el paso 3 de abajo.
5. La clave cacheada para biometría (ADR 0010) queda obsoleta. Se borra y se intenta guardar la nueva; si el sistema lo impide, el usuario la reactiva en Seguridad.
6. Cuenta como un ingreso de la contraseña maestra para el recordatorio (ADR 0017).

La lógica de sync entra por un puerto del dominio de `vault`, `MasterPasswordChangeReplicaPort`, con las operaciones `syncBeforeChange` y `publish`. `vault/application` no conoce la sync. Sin sync configurada, el adaptador no hace nada.

### 3. Los demás dispositivos (`AdoptRemoteMasterPasswordUseCase`)

- `SyncVaultUseCase` distingue un caso nuevo: el remoto es **la misma bóveda** (`vault_id`) pero con **otro salt**. Lo rechaza con `RemoteVaultRejection.passwordChanged`, sin tocar nada local, igual que en S1.
- La app avisa ("La contraseña maestra se cambió en otro dispositivo") y pide la contraseña nueva. Con ella:
  1. Deriva la clave con el header remoto y verifica el remoto con AEAD. Si falla, la contraseña es incorrecta y no se cambia nada.
  2. Si el local no cambió desde la última sync, adopta el remoto tal cual.
  3. Si el local cambió, hace un merge de 3 vías: el local y el ancestro se descifran con la clave vieja de la sesión, y el remoto con la nueva. El resultado se cifra con la clave y el header nuevos, se sube y se escribe localmente. No se pierden los cambios hechos con la contraseña vieja.
  4. La sesión pasa a la clave nueva, y la biometría y el recordatorio se tratan igual que en el paso 5 y 6 de arriba.

## Consecuencias

- Con sync configurada, cambiar la contraseña **requiere conexión**. Se acepta: la alternativa es dejar la nube con la contraseña vieja y a los otros dispositivos divergiendo.
- Los otros dispositivos no se actualizan solos: piden la contraseña nueva la próxima vez que sincronizan. Es deliberado, porque el salt nuevo hace imposible derivar sin ella.
- **Rollback (S2, pendiente):** quien controle la nube puede volver a subir un archivo viejo con el salt anterior. El dispositivo pediría "la contraseña nueva", y si el usuario escribiera la **vieja**, adoptaría el archivo viejo. El texto del aviso lo hace sospechoso para quien acaba de cambiarla, pero la protección real es el contador monotónico de S2, que tendrá su propio ADR.
- Quien conozca la contraseña **vieja** y tenga una copia vieja del archivo sigue pudiendo leer esa copia. Cambiar la contraseña protege las versiones nuevas, no las ya filtradas. Es inherente al modelo de archivo cifrado y queda documentado para no prometer otra cosa en la UI.
- Un atacante con acceso a la nube podría subir un archivo con el mismo `vault_id` y otro salt para provocar el aviso. La contraseña que se escribe solo se usa localmente, así que no se filtra nada: el descifrado falla y no se cambia nada. Los parámetros de KDF de ese header están acotados por S3.
