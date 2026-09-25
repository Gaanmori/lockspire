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

  /// Límites que se aceptan al **leer** un archivo de bóveda (revisión
  /// 2026-09-25, hallazgo S3). El header viene del archivo, que puede venir
  /// de la nube: sin límites, un archivo manipulado podía pedir decenas de
  /// GiB de memoria o miles de millones de iteraciones y colgar o tumbar la
  /// app al desbloquear.
  ///
  /// - Mínimos: los de ADR 0002 (≥256 MiB, ≥3 iteraciones). Un archivo con
  ///   menos no es de Lockspire o está degradado.
  /// - Máximos: 2 GiB y 32 iteraciones, holgados respecto al valor por
  ///   defecto (512 MiB, 4) para poder subirlo en el futuro.
  /// - Paralelismo: exactamente 1 (ADR 0007).
  static const minMemoryKib = 256 * 1024;
  static const maxMemoryKib = 2 * 1024 * 1024;
  static const minIterations = 3;
  static const maxIterations = 32;

  bool get isWithinAcceptedBounds =>
      memoryKib >= minMemoryKib &&
      memoryKib <= maxMemoryKib &&
      iterations >= minIterations &&
      iterations <= maxIterations &&
      parallelism == 1;
}
