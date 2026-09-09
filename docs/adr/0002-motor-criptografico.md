# 0002 — Motor criptográfico: librería y algoritmos

- Estado: Aceptado
- Fecha: 2026-09-09

## Contexto

Necesitamos elegir librería de criptografía y algoritmos para la derivación de clave y el cifrado de la bóveda. Principio rector del proyecto: la seguridad prevalece sobre el rendimiento.

## Decisión

- **Librería: bindings nativos de libsodium** (vía un binding FFI/plugin como `sodium_libs`/`flutter_sodium`, o `cryptography_flutter` cuando delega en BoringSSL/libsodium nativo), no el paquete `cryptography` en modo puro-Dart. Razón: libsodium es una implementación de referencia, revisada externamente, con protecciones contra timing attacks que una reimplementación en Dart puro no garantiza.
- **KDF: Argon2id.** Parámetros agresivos por defecto: memoria ≥256 MiB, iteraciones ≥3-4, paralelismo acorde a núcleos — validar con benchmarking real en el dispositivo de pruebas (Redmi Note 15 Pro+ 5G, Snapdragon 7s Gen 4). Nunca bajar estos parámetros por rendimiento; si el desbloqueo tarda en un dispositivo más limitado, se resuelve con UX (indicador de progreso, desbloqueo biométrico tras el primer login).
- **Cifrado simétrico: XChaCha20-Poly1305.** Nonce de 192 bits generado aleatoriamente en cada operación, sin necesidad de contador estricto entre dispositivos.
- **AAD anti-downgrade:** los parámetros de la cabecera del archivo de bóveda (versión de formato, parámetros de Argon2id, salt) van como datos autenticados (AAD) dentro del AEAD, para que una manipulación de la cabecera invalide la autenticación en vez de debilitar silenciosamente los parámetros.
- **Salt y clave nuevos en cada cambio de contraseña maestra** (rotación completa).

## Alternativas consideradas

- Paquete `cryptography` en Dart puro: más simple de integrar (sin FFI), pero sin las garantías de una implementación de referencia auditada — descartado dado que seguridad prevalece sobre conveniencia de desarrollo.
- AES-256-GCM en vez de XChaCha20-Poly1305: descartado por el riesgo de colisión de nonce (96 bits) en un archivo que se reescribe constantemente, frente a los 192 bits de XChaCha20.
