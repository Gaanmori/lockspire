// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Parámetros de Argon2id usados para derivar la clave de una bóveda.
/// Ver docs/adr/0002-motor-criptografico.md para los valores mínimos
/// recomendados (memoria ≥256 MiB, iteraciones ≥3-4) y
/// docs/adr/0007-paralelismo-argon2id-libsodium.md para por qué
/// [parallelism] siempre debe ser `1` en la práctica.
class Argon2Params {
  final int memoryKib;
  final int iterations;
  final int parallelism;

  const Argon2Params({
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
  });
}
