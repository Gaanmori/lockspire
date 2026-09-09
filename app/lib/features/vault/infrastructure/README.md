# infrastructure/ — feature `vault`

Pendiente (fase posterior): adaptador de `CryptoPort` con bindings nativos de libsodium (ver `docs/adr/0002-motor-criptografico.md`) y adaptador de `VaultStoragePort` con escritura atómica de archivo (temporal + fsync + rename, ver `CLAUDE.md`).

Los adaptadores implementan los puertos definidos en `../domain/ports/` — no deben contener lógica de negocio.
