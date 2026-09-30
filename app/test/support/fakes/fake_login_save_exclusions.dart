// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/browser_bridge/domain/ports/login_save_exclusions_port.dart';

/// Los sitios donde no se ofrece guardar contraseñas, en memoria.
class FakeLoginSaveExclusions implements LoginSaveExclusionsPort {
  final sites = <String>{};

  @override
  Future<Set<String>> all() async => {...sites};

  @override
  Future<void> exclude(String site) async => sites.add(site);

  @override
  Future<void> include(String site) async => sites.remove(site);

  @override
  Future<bool> isExcluded(String site) async => sites.contains(site);
}
