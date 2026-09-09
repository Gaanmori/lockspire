# 0004 — Formato de archivo de bóveda v1

- Estado: Aceptado
- Fecha: 2026-09-09

## Contexto

Con el motor criptográfico ya decidido ([ADR 0002](0002-motor-criptografico.md): Argon2id + XChaCha20-Poly1305, AAD anti-downgrade) hace falta definir el formato binario del archivo de bóveda: qué va cifrado, qué va como metadata autenticada, y cómo se estructuran las entradas por dentro. Ver [Threat Model](../THREAT_MODEL.md) para el análisis de adversarios que motiva el versionado explícito y el rechazo de degradación silenciosa.

Se decidió (usuario) que v1 usa un **blob único cifrado** — todo el archivo es un solo AEAD — en vez de cifrado por entrada dentro de un contenedor, priorizando simplicidad de implementación y auditoría sobre la posibilidad de sync incremental.

## Decisión

### Estructura del archivo

```
[MAGIC "LKSP"] [version_formato: u16] [header_len: u32]
[HEADER — sin cifrar, autenticado como AAD del AEAD]
  - version_formato (u16)
  - format_min_reader_version (u16)   # un lector con versión menor DEBE rechazar, nunca degradar en silencio
  - kdf: "argon2id"
  - kdf_params: { memory_kib, iterations, parallelism }
  - salt (32 bytes, aleatorio, nuevo en cada cambio de contraseña maestra — ver ADR 0002)
  - nonce (24 bytes, XChaCha20)
  - vault_id (UUID v4 — identidad estable de la bóveda a través de renombres/copias del archivo; lo usa el sync para saber qué archivos remotos corresponden a la misma bóveda)
  - created_at
[CIPHERTEXT + TAG de Poly1305]  # XChaCha20-Poly1305 sobre el payload, con el HEADER completo como AAD
```

Que el header vaya como AAD (no cifrado, pero autenticado) es intencional: cualquier manipulación de los parámetros de Argon2id, el salt o la versión de formato invalida la autenticación completa del archivo, en vez de permitir un downgrade silencioso de parámetros — coherente con la decisión ya tomada en ADR 0002.

### Payload cifrado (una vez desencriptado)

Serializado en **JSON**. Se prefiere sobre CBOR por simplicidad de debugging durante desarrollo — el tamaño de una bóveda de contraseñas es irrelevante para el overhead de JSON frente a un formato binario, así que esto es una decisión de ergonomía, no de seguridad, y es reversible en una v2 del formato sin tocar el motor criptográfico.

```json
{
  "schema_version": 1,
  "vault_id": "<debe coincidir con el vault_id del header>",
  "folders": [
    { "id": "<uuid>", "name": "...", "modified_at": "..." }
  ],
  "entries": [
    {
      "id": "<uuid>",
      "type": "password | passkey | note | ...",
      "title": "...",
      "modified_at": "<timestamp>",
      "created_at": "<timestamp>",
      "deleted": false,
      "deleted_at": null,
      "...campos específicos según type": "..."
    }
  ]
}
```

Los campos `modified_at` y `deleted`/`deleted_at` (tombstone) por entrada existen específicamente para habilitar el merge Last-Write-Wins definido en [ADR 0006](0006-modelo-resolucion-conflictos.md) — no son metadata incidental.

### Escritura

La escritura del archivo sigue la regla ya fijada en `CLAUDE.md`: siempre atómica (temporal + fsync + rename), nunca sobrescritura en sitio. Este ADR no la redecide, solo la asume.

### Versionado

Un lector que encuentre `format_min_reader_version` mayor a la versión que soporta debe **rechazar explícitamente** el archivo (error claro al usuario: "actualiza la app"), nunca intentar un parseo best-effort que podría interpretar mal datos de un formato futuro.

## Alternativas consideradas

- **Cifrado por entrada dentro de un contenedor común:** permitiría sync incremental (no reescribir todo el archivo en cada cambio) y conflictos más finos por campo. Descartado para v1 por la complejidad adicional del formato y la superficie de bugs en el parser — se puede reconsiderar en una v2 si el volumen de datos lo justifica.
- **CBOR en vez de JSON para el payload interno:** más compacto y sin ambigüedad de tipos, pero peor para debugging manual durante desarrollo. Se documenta como alternativa válida para una futura revisión de formato, no descartada de forma permanente.
