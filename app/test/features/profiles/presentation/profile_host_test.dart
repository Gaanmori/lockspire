// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/profiles/domain/profile.dart';
import 'package:lockspire/features/profiles/presentation/profile_switcher.dart';
import 'package:lockspire/features/profiles/presentation/widgets/profile_host.dart';
import 'package:lockspire/shared/active_profile_provider.dart';

class _ActiveProfile extends ConsumerWidget {
  const _ActiveProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(ref.watch(activeProfileIdProvider)),
  );
}

void main() {
  final booted = <String>[];

  Future<ProviderContainer> boot(String id, ProfileSwitcher _) async {
    booted.add(id);
    if (id == 'roto') throw StateError('no arranca');
    return ProviderContainer(
      overrides: [activeProfileIdProvider.overrideWithValue(id)],
    );
  }

  setUp(booted.clear);

  testWidgets('cambia de contenedor, descarta el anterior y, si un perfil '
      'no arranca, abre el principal', (tester) async {
    final handle = ProfileSwitchHandle();
    final first = await boot('p2', handle);
    final seen = <ProviderContainer>[];
    final left = <ProviderContainer>[];
    await tester.pumpWidget(
      ProfileHost(
        handle: handle,
        initialContainer: first,
        boot: boot,
        onLeave: left.add,
        onContainer: seen.add,
        child: const _ActiveProfile(),
      ),
    );
    expect(find.text('p2'), findsOneWidget);

    var erased = false;
    final opening = handle.open(
      'roto',
      afterLeaving: () async => erased = true,
    );
    await tester.pumpAndSettle();
    await opening;
    await tester.pumpAndSettle();

    expect(erased, isTrue);
    expect(booted, ['p2', 'roto', mainProfileId]);
    expect(find.text(mainProfileId), findsOneWidget);
    expect(seen, hasLength(1));
    expect(left, [first]);
    // El contenedor anterior quedó descartado.
    expect(() => first.read(activeProfileIdProvider), throwsStateError);
  });

  test('sin ProfileHost montado no se puede cambiar', () {
    expect(() => ProfileSwitchHandle().open('p2'), throwsStateError);
  });
}
