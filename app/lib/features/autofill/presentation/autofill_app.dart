// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import '../../appearance/presentation/providers/app_locale_provider.dart';
import '../../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/lockspire_icon.dart';
import '../../../design/lockspire_spacing.dart';
import '../../appearance/presentation/providers/app_icon_colors_provider.dart';
import '../../appearance/presentation/providers/app_themes_provider.dart';
import '../../vault/presentation/screens/unlock_vault_screen.dart';
import '../../vault/presentation/vault_session_controller.dart';
import '../../vault/presentation/vault_session_state.dart';
import 'screens/autofill_screen.dart';
import 'package:lockspire/l10n/localized_error.dart';

/// Raíz de la app cuando `AutofillActivity` (ADR 0011) la lanza — activada
/// por `main.dart` cuando la ruta inicial es `/autofill` (ver
/// `AutofillActivity.getInitialRoute()`). Reusa el flujo de desbloqueo
/// normal (contraseña o biometría) sin ningún camino nuevo; solo cambia
/// qué pantalla se muestra una vez desbloqueada.
class AutofillApp extends ConsumerWidget {
  const AutofillApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(appThemesProvider);
    return LockspireBrand(
      colors: ref.watch(appIconColorsProvider),
      child: MaterialApp(
        title: 'Lockspire',
        locale: ref.watch(appLocaleProvider),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeListResolutionCallback: (locales, _) =>
            resolveSystemLocale(locales),
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themes.mode,
        home: const _AutofillGate(),
      ),
    );
  }
}

class _AutofillGate extends ConsumerWidget {
  const _AutofillGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(vaultSessionControllerProvider);

    return asyncState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: Text(
              context.l10n.commonErrorDetail(
                localizeError(context.l10n, error),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (state) => switch (state) {
        VaultSessionUnlocked(:final vault) => AutofillScreen(vault: vault),
        VaultSessionLocked() => const UnlockVaultScreen(
          checkCloudForPasswordChange: false,
        ),
        // No debería pasar en la práctica (autofill solo tiene sentido con
        // una bóveda ya creada) — se cubre igual para no crashear.
        VaultSessionNoVault() => const _NoVaultView(),
      },
    );
  }
}

class _NoVaultView extends StatelessWidget {
  const _NoVaultView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(LockspireSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.autofillNoVault, textAlign: TextAlign.center),
              const SizedBox(height: LockspireSpacing.lg),
              FilledButton(
                onPressed: () => const MethodChannel(
                  'com.lockspire.lockspire/autofill',
                ).invokeMethod('cancel'),
                child: Text(context.l10n.commonClose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
