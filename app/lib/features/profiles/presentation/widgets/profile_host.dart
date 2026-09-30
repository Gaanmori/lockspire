// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/profile.dart';
import '../profile_switcher.dart';

/// Crea y arranca el contenedor de un perfil. Tiene que poner
/// `activeProfileIdProvider` y `profileSwitcherProvider` en sus overrides.
typedef BootProfile =
    Future<ProviderContainer> Function(
      String profileId,
      ProfileSwitcher switcher,
    );

/// El [ProfileSwitcher] de la app: lo crea `main()` antes que el primer
/// contenedor (que lo necesita en sus overrides) y [ProfileHost] se
/// engancha a él al montarse.
class ProfileSwitchHandle implements ProfileSwitcher {
  _ProfileHostState? _host;

  @override
  Future<void> open(String profileId, {Future<void> Function()? afterLeaving}) {
    final host = _host;
    if (host == null) throw StateError('ProfileHost no está montado');
    return host._open(profileId, afterLeaving);
  }
}

/// La raíz de la app con perfiles (ADR 0039): muestra [child] con el
/// contenedor del perfil abierto y, al cambiar, lo reemplaza entero. Así
/// nada de un perfil (la clave en memoria, un token de nube, el canal del
/// navegador) sigue vivo en el otro.
class ProfileHost extends StatefulWidget {
  final ProfileSwitchHandle handle;
  final ProviderContainer initialContainer;
  final BootProfile boot;

  /// Lo que se hace con el perfil actual antes de descartarlo (bloquear la
  /// bóveda). Lo pone la raíz de la app: esta feature no conoce la bóveda.
  final void Function(ProviderContainer container) onLeave;
  final Widget child;

  /// Cada contenedor nuevo, para quien necesite leerlo (los tests).
  final ValueChanged<ProviderContainer>? onContainer;

  const ProfileHost({
    super.key,
    required this.handle,
    required this.initialContainer,
    required this.boot,
    required this.onLeave,
    required this.child,
    this.onContainer,
  });

  @override
  State<ProfileHost> createState() => _ProfileHostState();
}

class _ProfileHostState extends State<ProfileHost> {
  /// `null` mientras se cambia de perfil: no hay app montada.
  late ProviderContainer? _container = widget.initialContainer;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    widget.handle._host = this;
  }

  Future<void> _open(
    String profileId,
    Future<void> Function()? afterLeaving,
  ) async {
    if (_switching) return;
    _switching = true;
    try {
      final old = _container;
      if (old != null) {
        widget.onLeave(old);
        // Desmontar la app antes de descartar su contenedor.
        setState(() => _container = null);
        await WidgetsBinding.instance.endOfFrame;
        old.dispose();
      }
      await afterLeaving?.call();
      ProviderContainer next;
      try {
        next = await widget.boot(profileId, widget.handle);
      } catch (_) {
        // Si el perfil no arranca, se abre el principal antes que dejar
        // la app en blanco.
        if (profileId == mainProfileId) rethrow;
        next = await widget.boot(mainProfileId, widget.handle);
      }
      if (!mounted) {
        next.dispose();
        return;
      }
      widget.onContainer?.call(next);
      setState(() => _container = next);
    } finally {
      _switching = false;
    }
  }

  @override
  void dispose() {
    if (widget.handle._host == this) widget.handle._host = null;
    _container?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final container = _container;
    if (container == null) return const _Opening();
    return UncontrolledProviderScope(
      // Key por contenedor: todo el árbol (navegación, estado de pantallas)
      // se crea de nuevo con el perfil nuevo.
      key: ObjectKey(container),
      container: container,
      child: widget.child,
    );
  }
}

/// Lo que se ve el instante en que se cambia de perfil. Sin textos: todavía
/// no hay idioma ni tema del perfil nuevo.
class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) => const Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: Color(0xFF2B2E32),
      child: Center(child: CircularProgressIndicator(color: Color(0xFFF7F7F8))),
    ),
  );
}
