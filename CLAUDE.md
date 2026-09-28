# Instrucciones para Claude (y cualquier otro agente) en este repo

Lockspire es un gestor de contraseñas y Passkeys open source, local-first, multiplataforma (Flutter/Dart + extensión TypeScript). Antes de tocar código, lee `docs/STATE.md` (dónde estamos ahora) y los ADRs relevantes en `docs/adr/`.

## Principios que no se reabren sin que el usuario lo pida explícitamente

1. **Seguridad por encima de rendimiento**, siempre. Ante cualquier disyuntiva, resolver a favor de la opción más segura.
2. **Criptografía:** libsodium vía bindings nativos (no reimplementaciones puras en Dart) para Argon2id y XChaCha20-Poly1305. Parámetros de Argon2id agresivos por defecto (memoria ≥256 MiB, iteraciones ≥3-4).
3. **Arquitectura:** Clean Architecture organizada como Hexagonal (Puertos y Adaptadores), por features, dentro de `app/lib/features/<feature>/{domain,application,infrastructure,presentation}`. El dominio nunca importa nada de `infrastructure/` ni `presentation/`. Los adaptadores nunca contienen lógica de negocio.
4. **Fuera de alcance:** autocompletado dentro de apps de escritorio de Windows que no sean el navegador (mecanismo "auto-type"). No trabajar en esto salvo petición explícita del usuario.
5. **Licencia:** AGPLv3. Todo archivo de código nuevo debería llevar la cabecera de licencia correspondiente.

## Flujo de trabajo esperado en cada sesión

- Lee `docs/STATE.md` al empezar para saber en qué fase estamos y qué quedó pendiente.
- Antes de una decisión de arquitectura importante, revisa si ya existe un ADR en `docs/adr/` que la cubra — no la reabras sin motivo.
- Si tomas una decisión de arquitectura nueva, créala como un ADR nuevo (`docs/adr/NNNN-titulo.md`), inmutable una vez aceptado. Si cambias de opinión sobre un ADR anterior, crea uno nuevo que lo referencie como "superseded by", no lo edites.
- **Al terminar la sesión de trabajo, actualiza `docs/STATE.md`** con: fase actual, qué se completó, qué queda pendiente, y cualquier bloqueo o decisión abierta. Es lo primero que lee la siguiente sesión.
- Código de criptografía y sincronización siempre acompañado de tests (vectores de prueba conocidos para primitivas criptográficas).

## Convenciones de código

- Gestión de estado: Riverpod (con code generation).
- Cada proveedor de sync (Drive/OneDrive/Dropbox/WebDAV) es un adaptador independiente de `SyncPort` en `features/sync/infrastructure` — añadir uno nuevo no debe tocar dominio ni casos de uso.
- Código nativo (Kotlin, Swift, C++) vive en la ubicación estándar de cada plataforma (`android/app/src/main/kotlin/...`, `windows/runner/`…), según el ADR 0021. Es delgado: no tiene lógica de negocio ni toca la bóveda, y cada canal tiene su adaptador Dart en `features/<feature>/infrastructure`, detrás de un puerto.
- Escritura del archivo de bóveda siempre atómica (temporal + fsync + rename), nunca sobrescritura en sitio.
