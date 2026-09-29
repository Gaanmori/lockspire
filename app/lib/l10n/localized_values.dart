// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/vault/application/password_strength_estimator.dart';
import 'package:lockspire/features/vault/domain/ports/vault_exporter.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import 'generated/app_localizations.dart';

/// Valores de dominio y aplicación puestos en palabras en el idioma de la
/// app (ADR 0032).
extension LocalizedValues on AppLocalizations {
  /// "la huella" / "Windows Hello", para usar dentro de una frase.
  String biometricName(BiometricMethod method) => switch (method) {
    BiometricMethod.windowsHello => biometricWindowsHello,
    BiometricMethod.fingerprint => biometricFingerprint,
  };

  String crackTimeText(CrackTime time) => switch (time.unit) {
    CrackTimeUnit.instant => crackTimeInstant,
    CrackTimeUnit.seconds => crackTimeSeconds(time.amount),
    CrackTimeUnit.minutes => crackTimeMinutes(time.amount),
    CrackTimeUnit.hours => crackTimeHours(time.amount),
    CrackTimeUnit.days => crackTimeDays(time.amount),
    CrackTimeUnit.months => crackTimeMonths(time.amount),
    CrackTimeUnit.years => crackTimeYears(time.amount),
    CrackTimeUnit.centuries => crackTimeCenturies(time.amount),
    CrackTimeUnit.millionsOfYears => crackTimeMillionsOfYears,
  };

  String exportFormatLabel(ExportFormat format) => switch (format) {
    ExportFormat.bitwardenCsv => exportBitwardenCsv,
    ExportFormat.bitwardenJson => exportBitwardenJson,
    ExportFormat.chromeCsv => exportChromeCsv,
  };

  String exportFormatDescription(ExportFormat format) => switch (format) {
    ExportFormat.bitwardenCsv => exportBitwardenCsvHint,
    ExportFormat.bitwardenJson => exportBitwardenJsonHint,
    ExportFormat.chromeCsv => exportChromeCsvHint,
  };
}
