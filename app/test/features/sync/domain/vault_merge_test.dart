// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/domain/vault_merge.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

VaultEntry _entry(
  String id,
  String title, {
  DateTime? modifiedAt,
  bool deleted = false,
  DateTime? deletedAt,
  Map<String, String> fields = const {},
}) {
  final t = modifiedAt ?? DateTime.utc(2026, 1, 1);
  return VaultEntry(
    id: id,
    type: VaultEntryType.password,
    title: title,
    createdAt: t,
    modifiedAt: t,
    deleted: deleted,
    deletedAt: deletedAt,
    fields: fields,
  );
}

Vault _vault(List<VaultEntry> entries) =>
    Vault(vaultId: 'v1', schemaVersion: 1, entries: entries);

void main() {
  group('mergeVaults — ramas automáticas', () {
    test('entrada nueva solo en local se incluye, sin conflicto', () {
      final analysis = mergeVaults(
        ancestor: null,
        local: _vault([_entry('a', 'Nueva local')]),
        remote: _vault([]),
      );

      expect(analysis.hasConflicts, isFalse);
      expect(analysis.autoMerged.entries.map((e) => e.id), ['a']);
    });

    test('entrada nueva solo en remoto se incluye, sin conflicto', () {
      final analysis = mergeVaults(
        ancestor: null,
        local: _vault([]),
        remote: _vault([_entry('a', 'Nueva remota')]),
      );

      expect(analysis.hasConflicts, isFalse);
      expect(analysis.autoMerged.entries.map((e) => e.id), ['a']);
    });

    test('mismo contenido en ambos lados → sin conflicto', () {
      final ancestor = _vault([_entry('a', 'Original')]);
      final analysis = mergeVaults(
        ancestor: ancestor,
        local: _vault([_entry('a', 'Original')]),
        remote: _vault([_entry('a', 'Original')]),
      );

      expect(analysis.hasConflicts, isFalse);
      expect(analysis.autoResolvedCount, 0);
    });

    test('cambió solo local desde el ancestro → gana local, automático', () {
      final ancestor = _vault([_entry('a', 'Original')]);
      final analysis = mergeVaults(
        ancestor: ancestor,
        local: _vault([
          _entry('a', 'Editada', modifiedAt: DateTime.utc(2026, 2)),
        ]),
        remote: _vault([_entry('a', 'Original')]),
      );

      expect(analysis.hasConflicts, isFalse);
      expect(analysis.autoResolvedCount, 1);
      expect(analysis.autoMerged.entries.single.title, 'Editada');
    });

    test('cambió solo remoto desde el ancestro → gana remoto, automático', () {
      final ancestor = _vault([_entry('a', 'Original')]);
      final analysis = mergeVaults(
        ancestor: ancestor,
        local: _vault([_entry('a', 'Original')]),
        remote: _vault([
          _entry('a', 'Editada en remoto', modifiedAt: DateTime.utc(2026, 2)),
        ]),
      );

      expect(analysis.hasConflicts, isFalse);
      expect(analysis.autoResolvedCount, 1);
      expect(analysis.autoMerged.entries.single.title, 'Editada en remoto');
    });

    test(
      'borrado local + edición remota posterior → revive con la versión remota',
      () {
        final ancestor = _vault([_entry('a', 'Original')]);
        final deletedAt = DateTime.utc(2026, 2);
        final analysis = mergeVaults(
          ancestor: ancestor,
          local: _vault([
            _entry(
              'a',
              'Original',
              deleted: true,
              deletedAt: deletedAt,
              modifiedAt: deletedAt,
            ),
          ]),
          remote: _vault([
            _entry(
              'a',
              'Editada después del borrado',
              modifiedAt: DateTime.utc(2026, 3),
            ),
          ]),
        );

        expect(analysis.hasConflicts, isFalse);
        final result = analysis.autoMerged.entries.single;
        expect(result.deleted, isFalse);
        expect(result.title, 'Editada después del borrado');
      },
    );

    test(
      'borrado remoto + edición local posterior → revive con la versión local',
      () {
        final ancestor = _vault([_entry('a', 'Original')]);
        final deletedAt = DateTime.utc(2026, 2);
        final analysis = mergeVaults(
          ancestor: ancestor,
          local: _vault([
            _entry(
              'a',
              'Editada después del borrado',
              modifiedAt: DateTime.utc(2026, 3),
            ),
          ]),
          remote: _vault([
            _entry(
              'a',
              'Original',
              deleted: true,
              deletedAt: deletedAt,
              modifiedAt: deletedAt,
            ),
          ]),
        );

        expect(analysis.hasConflicts, isFalse);
        final result = analysis.autoMerged.entries.single;
        expect(result.deleted, isFalse);
        expect(result.title, 'Editada después del borrado');
      },
    );

    test('ambos borraron la misma entrada → sin conflicto, queda borrada', () {
      final ancestor = _vault([_entry('a', 'Original')]);
      final deletedAt = DateTime.utc(2026, 2);
      final analysis = mergeVaults(
        ancestor: ancestor,
        local: _vault([
          _entry(
            'a',
            'Original',
            deleted: true,
            deletedAt: deletedAt,
            modifiedAt: deletedAt,
          ),
        ]),
        remote: _vault([
          _entry(
            'a',
            'Original',
            deleted: true,
            deletedAt: deletedAt,
            modifiedAt: deletedAt,
          ),
        ]),
      );

      expect(analysis.hasConflicts, isFalse);
      expect(analysis.autoMerged.entries.single.deleted, isTrue);
    });
  });

  group('mergeVaults — conflicto real', () {
    test('cambió distinto en ambos lados (ni tombstone) → queda en conflicts, '
        'no en autoMerged', () {
      final ancestor = _vault([_entry('a', 'Original')]);
      final analysis = mergeVaults(
        ancestor: ancestor,
        local: _vault([
          _entry('a', 'Editada en local', modifiedAt: DateTime.utc(2026, 2)),
        ]),
        remote: _vault([
          _entry(
            'a',
            'Editada distinto en remoto',
            modifiedAt: DateTime.utc(2026, 3),
          ),
        ]),
      );

      expect(analysis.hasConflicts, isTrue);
      expect(analysis.conflicts, hasLength(1));
      expect(analysis.conflicts.single.local.title, 'Editada en local');
      expect(
        analysis.conflicts.single.remote.title,
        'Editada distinto en remoto',
      );
      expect(analysis.autoMerged.entries, isEmpty);
    });

    test(
      'sin ancestro (null): entradas distintas con el mismo id → conflicto',
      () {
        final analysis = mergeVaults(
          ancestor: null,
          local: _vault([_entry('a', 'Versión local')]),
          remote: _vault([_entry('a', 'Versión remota')]),
        );

        expect(analysis.hasConflicts, isTrue);
        expect(analysis.conflicts.single.local.title, 'Versión local');
      },
    );

    test('sin ancestro (null): mismo contenido → sin conflicto', () {
      final analysis = mergeVaults(
        ancestor: null,
        local: _vault([_entry('a', 'Igual')]),
        remote: _vault([_entry('a', 'Igual')]),
      );

      expect(analysis.hasConflicts, isFalse);
    });

    test('el orden de las entradas no cambia el resultado', () {
      final ancestor = _vault([_entry('a', 'A'), _entry('b', 'B')]);
      final local = _vault([
        _entry('a', 'A editada', modifiedAt: DateTime.utc(2026, 2)),
        _entry('b', 'B editada distinto', modifiedAt: DateTime.utc(2026, 2)),
      ]);
      final remote = _vault([
        _entry(
          'b',
          'B editada distinto en remoto',
          modifiedAt: DateTime.utc(2026, 3),
        ),
        _entry('a', 'A editada', modifiedAt: DateTime.utc(2026, 2)),
      ]);

      final analysis1 = mergeVaults(
        ancestor: ancestor,
        local: local,
        remote: remote,
      );
      final analysis2 = mergeVaults(
        ancestor: _vault([_entry('b', 'B'), _entry('a', 'A')]),
        local: _vault(local.entries.reversed.toList()),
        remote: remote,
      );

      expect(analysis1.autoResolvedCount, analysis2.autoResolvedCount);
      expect(analysis1.conflicts.length, analysis2.conflicts.length);
      expect(
        analysis1.autoMerged.entries.map((e) => e.id).toSet(),
        analysis2.autoMerged.entries.map((e) => e.id).toSet(),
      );
    });
  });

  group('applyConflictResolutions', () {
    test('inserta la entrada elegida con su id original, sin duplicar', () {
      final autoMerged = _vault([_entry('untouched', 'Sin conflicto')]);
      final chosen = _entry('a', 'Elegida por el usuario');

      final result = applyConflictResolutions(autoMerged, {'a': chosen});

      expect(result.entries, hasLength(2));
      expect(
        result.entries.firstWhere((e) => e.id == 'a').title,
        'Elegida por el usuario',
      );
    });
  });
}
