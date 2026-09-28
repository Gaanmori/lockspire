# ADR 0027 — Exportar la bóveda e importar desde otros gestores

- **Estado:** Aceptado
- **Fecha:** 2026-09-28
- **Amplía:** ADR 0025 (keys de entrada), Fase 6 (import de SafeInCloud)
- **Origen:** requisito del MVP (nadie debería guardar sus contraseñas en un gestor del que no puede sacarlas). El usuario eligió los formatos.

## Decisión

### Exportar

| Formato | Cifrado | Qué lleva |
|---|---|---|
| **Respaldo de Lockspire** (`.lockspire`) | Sí, con la contraseña maestra | El archivo de la bóveda tal cual: todo. |
| **CSV de Bitwarden** | No | Contraseñas como `login`. Tarjetas y documentos como `note`, con sus datos en la columna `fields`. |
| **JSON de Bitwarden** | No | Contraseñas (`login`), tarjetas (`card`) y documentos (`identity`), con campos a medida e historial de contraseñas. |
| **CSV de Chrome** | No | Solo contraseñas, una fila por sitio. |

- **Contraseña maestra:** toda exportación la pide. La biometría no sirve para esto. Se verifica derivando la clave con el header actual y comparándola en tiempo constante con la de la sesión.
- **Advertencia antes:** los formatos sin cifrar la muestran antes de exportar.
- **Aviso después:** al terminar se recuerda borrar el archivo.
- **Sin copias intermedias:** el archivo se escribe solo donde el usuario elige, con el diálogo del sistema. Nunca se escribe una copia temporal propia.
- **Apps Android en Bitwarden:** se escriben como URIs `androidapp://<paquete>`, la convención de Bitwarden, y se leen igual al importar.
- **Tarjetas en el JSON de Bitwarden:** el PIN, que Bitwarden no tiene, va como campo oculto "PIN". Un vencimiento que no sea `MM/AA` va como campo "Vence".
- **Documentos en el JSON de Bitwarden:** el nombre va a `firstName`. El número y las fechas van como campos con los mismos nombres que usa Lockspire, así que el ida y vuelta es exacto.

### Importar

- **CSV:** el formato se reconoce por los encabezados: Bitwarden, Chrome/Edge/Google, Firefox, KeePassXC y, como último recurso, cualquier CSV con columnas reconocibles de usuario y contraseña. Filas con el mismo título, usuario y contraseña se unen en una entrada con varios sitios; Chrome exporta una fila por sitio.
- **JSON de Bitwarden sin cifrar:** logins, notas, tarjetas e identidades. Un JSON cifrado de Bitwarden se rechaza con un mensaje que explica cómo exportarlo sin cifrar.
- **Respaldo de Lockspire:** pide la contraseña **de ese respaldo**. El archivo pasa por las mismas validaciones que una bóveda (formato, límites de Argon2id) y se verifica con AEAD antes de usar nada.
- **Nunca duplicar:**
  - No se agregan entradas cuyo `id` ya existe. Esto evita ids repetidos al restaurar un respaldo de la misma bóveda.
  - Tampoco las que coinciden en tipo, título, usuario, contraseña y número (de tarjeta o documento) con una entrada existente.
  - Importar dos veces el mismo archivo no agrega nada.
- **TOTP:** no se genera (decisión del usuario, ADR 0025). Un secreto importado se guarda como campo oculto "TOTP" para no perderlo.

### Arquitectura

- Los formatos son adaptadores en `vault/infrastructure/interchange/`, detrás de los puertos `VaultImportSource` (existente) y `VaultExporter` (nuevo).
- La verificación de la contraseña maestra y la lectura del respaldo cifrado son casos de uso en `vault/application`.
- La regla de "no duplicar" es dominio puro.

## Consecuencias

- El usuario puede sacar todos sus datos de Lockspire en formatos abiertos, y traerlos de casi cualquier gestor.
- Los exports sin cifrar son el eslabón débil. Se mitiga con la advertencia y el aviso, pero su custodia depende del usuario (THREAT_MODEL, actor #8).
- Un respaldo de la misma bóveda no "resucita" entradas borradas después: su `id` ya existe como tombstone y se omite.
