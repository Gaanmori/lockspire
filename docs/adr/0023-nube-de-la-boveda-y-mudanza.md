# ADR 0023 — La bóveda sabe en qué nube vive, y cambiar de nube es una mudanza

- **Estado:** Aceptado
- **Fecha:** 2026-09-28
- **Origen:** el usuario notó que Windows sincronizaba con Google Drive y el Redmi con OneDrive, sin ningún aviso.

## Contexto

Cada dispositivo guarda su propio proveedor de sync activo. Nada impide que dos dispositivos usen nubes distintas, y entonces hay **dos copias de la bóveda que divergen en silencio**: los cambios de uno no llegan al otro. La protección contra rollback (ADR 0019) evita retroceder si un dispositivo cambia a una nube con una copia más vieja, pero no evita la divergencia.

## Decisión

### 1. La bóveda registra su nube (`Vault.syncHome`)

- Es un campo opcional del contenido cifrado (`sync_home`: `webdav`, `googleDrive` u `oneDrive`), así que viaja con la bóveda a todos los dispositivos.
- `vault` lo trata como un texto opaco y es `sync` quien lo interpreta, para no crear dependencias entre features (ADR 0003).
- **Merge:** si la nube lo cambió respecto del ancestro, gana la nube; si no, se queda el valor local. Así una mudanza hecha en otro dispositivo se propaga.

### 2. Sincronizar comprueba la nube (`SyncVaultUseCase`)

- Si la bóveda local dice que vive en otra nube, la sync **no sube ni baja nada** y lanza `SyncHomeMismatchException`. La app muestra un aviso.
- Si lo que baja de la nube dice que la bóveda **se mudó** (otra nube), se guarda localmente (fusionando lo local si hace falta), **no se sube nada** a la nube vieja y el resultado es `SyncVaultMoved`. La app muestra el aviso "su bóveda se mudó a X".
- Bóvedas sin `syncHome` (anteriores a este ADR): la primera sync con éxito lo fija con el proveedor activo.

### 3. Cambiar de nube es una mudanza (`MoveVaultToProviderUseCase`)

Al conectar otra nube con la bóveda desbloqueada, después de una confirmación:

1. Se sincroniza con la nube actual, para tener lo último.
2. Se marca `syncHome` con la nueva nube y se guarda (la revisión sube, ADR 0019).
3. Se sube esa versión a la **nube vieja**. Es el aviso de mudanza que van a recibir los demás dispositivos.
4. En la **nube nueva**:
   - Si ya hay una bóveda (la misma, por ejemplo porque otro dispositivo ya estaba ahí), se **fusiona** sin ancestro. Es la unión conservadora de ADR 0006: no se pierde nada de ninguno de los dos lados.
   - Si no hay, se sube.
   - Si hay **otra bóveda** (otro `vault_id`), se cancela sin tocar nada.
5. Se guarda la nube nueva como proveedor activo.

Si la bóveda está bloqueada o no existe (restaurar en un dispositivo nuevo), conectar una nube solo la activa, como antes.

## Consecuencias

- Los dispositivos ya no divergen en silencio. El que se queda en la nube vieja recibe el aviso y deja de subir ahí, así sus cambios esperan a que conecte la nueva y se fusionan entonces.
- Un dispositivo que nunca vuelve a sincronizar con la nube vieja no se entera de la mudanza hasta que lo hace. Es inherente a no tener un canal entre dispositivos fuera de la propia nube.
- El formato de la bóveda gana un campo opcional. Las versiones anteriores lo ignoran, pero si guardan, lo pierden. Todos los dispositivos deben actualizarse, igual que con ADR 0019.
