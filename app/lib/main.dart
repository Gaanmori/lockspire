// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/lockspire_theme.dart';
import 'features/vault/presentation/screens/vault_gate_screen.dart';
import 'features/vault/presentation/widgets/activity_and_lifecycle_watcher.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lockspire',
      theme: LockspireTheme.themeData,
      home: const ActivityAndLifecycleWatcher(child: VaultGateScreen()),
    );
  }
}
