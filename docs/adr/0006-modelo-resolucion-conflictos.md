# 0006 — Modelo de resolución de conflictos de sincronización

- Estado: Aceptado
- Fecha: 2026-09-09

## Contexto

Lockspire es local-first y sin backend central: varios dispositivos pueden editar la misma bóveda y sincronizarla a través de la nube personal del usuario (Drive/OneDrive/Dropbox/WebDAV), sin ningún servidor que coordine bloqueos o arbitre conflictos en tiempo real. Hace falta un modelo para cuando dos dispositivos modificaron la bóveda desde la última sincronización exitosa.

Este ADR depende directamente de [ADR 0004](0004-formato-boveda-v1.md): usa los campos `modified_at` y el tombstone (`deleted`/`deleted_at`) por entrada que ese formato ya reserva para este propósito.

Se decidió (usuario) **Last-Write-Wins (LWW) por entrada + tombstones + merge manual solo si hay choque real**, en vez de un CRDT completo — priorizando un motor simple y auditable sobre la robustez automática frente a ediciones simultáneas del mismo campo, un escenario raro en el uso real de un gestor de contraseñas personal.

## Decisión

### Mecanismo (merge de 3 vías con ancestro común)

1. Cada dispositivo cachea localmente el **snapshot desencriptado completo** de la última sincronización exitosa (no solo un hash) — es lo que permite distinguir, entrada por entrada, "cambié yo", "cambió el remoto" o "cambiamos ambos" respecto a ese ancestro común.
2. Al sincronizar: si el archivo remoto cambió desde el último snapshot conocido **y** el dispositivo local también tiene cambios sin sincronizar, se dispara el merge. Si solo uno de los dos lados cambió, no hay conflicto — se aplica directamente esa versión.
3. El merge desencripta ambas versiones (local y remota) en memoria —la app ya tiene la clave derivada de la sesión activa— y compara **entrada por entrada** por `id`:
   - Si solo un lado modificó una entrada desde el ancestro → gana esa modificación automáticamente, sin intervención del usuario.
   - Si **ambos** lados modificaron la **misma** entrada desde el ancestro → conflicto real → se presenta al usuario ambas versiones para que elija, o se conservan las dos como entradas separadas (patrón "mantener ambas", igual que otros gestores de contraseñas).
4. **Tombstones:** un borrado (`deleted=true`) posterior a la última edición conocida de esa entrada gana sobre ediciones más antiguas. Pero una edición **posterior** al borrado en otro dispositivo "revive" la entrada — evita que un dispositivo desactualizado resucite accidentalmente algo borrado a propósito, mientras respeta una edición intencional posterior.
5. Tras resolver el merge (automático o con input del usuario), el resultado se re-encripta como un nuevo blob único (formato de [ADR 0004](0004-formato-boveda-v1.md)) y se sube; el snapshot local de referencia se actualiza a esta nueva versión.

### Fuera de alcance v1

Sincronización en tiempo real con lock distribuido entre dispositivos. Al no existir backend central que coordine locks, se acepta que la sincronización sea al abrir la app, manual o periódica — no instantánea.

## Alternativas consideradas

- **CRDT completo:** garantizaría merge automático y consistente incluso en edición simultánea del mismo campo, sin intervención del usuario en ningún caso. Descartado por el usuario: la complejidad de implementación y la superficie de bugs adicional en código que maneja datos sensibles no se justifican para un escenario (edición simultánea del mismo password en dos dispositivos a la vez) extremadamente raro en el uso real.
