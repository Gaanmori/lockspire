# 0007 — Paralelismo de Argon2id fijado a 1 (limitación de libsodium)

- Estado: Aceptado
- Fecha: 2026-09-09

## Contexto

[ADR 0002](0002-motor-criptografico.md) pedía "paralelismo acorde a núcleos" para Argon2id. Al implementar el adaptador real de `CryptoPort` con libsodium (ver [ADR 0002](0002-motor-criptografico.md)) se confirmó que la API de alto nivel `crypto_pwhash` — la única que exponen los bindings de Dart (`sodium`) — **fija el paralelismo en 1 hilo por diseño**, por compatibilidad hacia atrás del propio proyecto libsodium. No es una limitación de la librería Dart elegida: es del API pública de libsodium en sí (las funciones internas de Argon2 que sí soportan paralelismo configurable no forman parte de la superficie pública soportada, y usarlas significaría depender de código no documentado/no garantizado entre versiones).

Este ADR no reabre ni contradice el ADR 0002 — documenta un hallazgo de implementación y fija la corrección necesaria.

## Decisión

- **Paralelismo: fijo en 1**, aceptando la limitación de la API pública de libsodium. Es la misma limitación que acepta software como Bitwarden al construir sobre libsodium.
- **Compensación:** se sube memoria e iteraciones por encima de los mínimos ya fijados en ADR 0002 para mantener el costo computacional alto pese al hilo único. Nuevos valores por defecto: **memoria 512 MiB** (antes ≥256 MiB), **iteraciones 4** (sin cambio). Sujeto a benchmarking real en el dispositivo de pruebas antes de v1 final, como ya preveía ADR 0002.
- **Regla dura para evitar pérdida de datos irreversible:** el campo `parallelism` del dominio (`Argon2Params`) se fija literalmente en `1` — nunca un valor "acorde a núcleos" aspiracional — porque ese valor viaja dentro del header persistido de la bóveda (autenticado como AAD, [ADR 0004](0004-formato-boveda-v1.md)) y es el que cualquier lector futuro necesita para re-derivar la misma clave. Si el valor guardado en el header llegara a no coincidir con el valor realmente usado por `crypto_pwhash` (que siempre es 1), el usuario quedaría permanentemente fuera de su propia bóveda — no es un problema de seguridad, es un bug de pérdida de datos.
- **Defensa en profundidad:** el adaptador (`SodiumCryptoAdapter.deriveKey()`) valida explícitamente que `params.parallelism == 1` antes de derivar, y lanza una excepción si recibe cualquier otro valor — nunca ignora en silencio un valor distinto que alguien pudiera introducir por error en el futuro.

## Alternativas consideradas

- **Usar una librería de Argon2 distinta de libsodium para lograr paralelismo real configurable.** Descartada: reintroduce exactamente el riesgo de auditoría que el ADR 0002 buscaba evitar al elegir libsodium como implementación de referencia — una segunda librería criptográfica, menos revisada, solo para ganar un parámetro de rendimiento que no es crítico para la seguridad del esquema (memoria e iteraciones altas ya hacen costoso un ataque de fuerza bruta con un solo hilo).
