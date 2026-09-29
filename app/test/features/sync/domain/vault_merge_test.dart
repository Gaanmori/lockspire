// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/domain/vault_merge.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

import '../../../support/builders.dart';

VaultEntry _entry(
  String id,
  String title, {
  DateTime? modifiedAt,
  bool deleted = false,
  DateTime? deletedAt,
  Map<String, String> fields = const {},
  Map<String, List<FieldHistoryRecord>> fieldHistory = const {},
}) => anEntry(
  id: id,
  title: title,
  createdAt: modifiedAt,
  deleted: deleted,
  deletedAt: deletedAt,
  fields: fields,
  fieldHistory: fieldHistory,
);

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

      expect(analysis.autoMerged.entries.map((e) => e.id), ['a']);
    });

    test('entrada nueva solo en remoto se incluye, sin conflicto', () {
      final analysis = mergeVaults(
        ancestor: null,
        local: _vault([]),
        remote: _vault([_entry('a', 'Nueva remota')]),
      );

      expect(analysis.autoMerged.entries.map((e) => e.id), ['a']);
    });

    test('mismo contenido en ambos lados → sin conflicto', () {
      final ancestor = _vault([_entry('a', 'Original')]);
      final analysis = mergeVaults(
        ancestor: ancestor,
        local: _vault([_entry('a', 'Original')]),
        remote: _vault([_entry('a', 'Original')]),
      );

      expect(analysis.autoResolvedCount, 0);
      expect(analysis.fieldConflictsResolved, 0);
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

      expect(analysis.autoResolvedCount, 1);
      expect(analysis.fieldConflictsResolved, 0);
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

      expect(analysis.autoResolvedCount, 1);
      expect(analysis.fieldConflictsResolved, 0);
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

      expect(analysis.autoMerged.entries.single.deleted, isTrue);
    });
  });

  group(
    'mergeVaults — merge por campo (ADR 0009, reemplaza el picker manual)',
    () {
      test('Nivel 1: campos distintos cambiados en cada lado se combinan sin '
          'preguntar nada, sin historial', () {
        final ancestor = _vault([
          _entry(
            'a',
            'Banco',
            fields: {'username': 'u', 'url': 'https://viejo.test'},
          ),
        ]);
        final analysis = mergeVaults(
          ancestor: ancestor,
          local: _vault([
            _entry(
              'a',
              'Banco',
              modifiedAt: DateTime.utc(2026, 2),
              fields: {'username': 'u', 'url': 'https://nuevo.test'},
            ),
          ]),
          remote: _vault([
            _entry(
              'a',
              'Banco',
              modifiedAt: DateTime.utc(2026, 3),
              fields: {'username': 'u2', 'url': 'https://viejo.test'},
            ),
          ]),
        );

        expect(analysis.fieldConflictsResolved, 0);
        final result = analysis.autoMerged.entries.single;
        expect(result.fields['url'], 'https://nuevo.test');
        expect(result.fields['username'], 'u2');
        expect(result.fieldHistory, isEmpty);
      });

      test('Nivel 2: mismo campo cambiado distinto en ambos → gana el de '
          'modifiedAt más reciente, el perdedor queda en fieldHistory', () {
        final ancestor = _vault([
          _entry('a', 'Banco', fields: {'password': 'vieja'}),
        ]);
        final analysis = mergeVaults(
          ancestor: ancestor,
          local: _vault([
            _entry(
              'a',
              'Banco',
              modifiedAt: DateTime.utc(2026, 2, 1, 9), // más viejo
              fields: {'password': 'local-nueva'},
            ),
          ]),
          remote: _vault([
            _entry(
              'a',
              'Banco',
              modifiedAt: DateTime.utc(2026, 2, 1, 10), // más nuevo
              fields: {'password': 'remota-nueva'},
            ),
          ]),
        );

        expect(analysis.fieldConflictsResolved, 1);
        final result = analysis.autoMerged.entries.single;
        expect(result.fields['password'], 'remota-nueva');
        expect(
          result.fieldHistory['password']!.map((r) => r.value),
          contains('local-nueva'),
        );
      });

      test('resultado es simétrico: no importa qué dispositivo corra el merge '
          '(comparar local vs remoto invertidos da el mismo ganador)', () {
        final ancestor = _vault([
          _entry('a', 'Banco', fields: {'password': 'vieja'}),
        ]);
        final earlier = _entry(
          'a',
          'Banco',
          modifiedAt: DateTime.utc(2026, 2, 1, 9),
          fields: {'password': 'de-las-9'},
        );
        final later = _entry(
          'a',
          'Banco',
          modifiedAt: DateTime.utc(2026, 2, 1, 10),
          fields: {'password': 'de-las-10'},
        );

        final asLocal = mergeVaults(
          ancestor: ancestor,
          local: _vault([earlier]),
          remote: _vault([later]),
        );
        final asRemote = mergeVaults(
          ancestor: ancestor,
          local: _vault([later]),
          remote: _vault([earlier]),
        );

        expect(
          asLocal.autoMerged.entries.single.fields['password'],
          'de-las-10',
        );
        expect(
          asRemote.autoMerged.entries.single.fields['password'],
          'de-las-10',
        );
      });

      test('ausencia de un campo (vaciado en un lado) se trata como un valor '
          'más — gana el vaciado si el otro lado no tocó ese campo', () {
        final ancestor = _vault([
          _entry('a', 'Banco', fields: {'notes': 'algo'}),
        ]);
        final analysis = mergeVaults(
          ancestor: ancestor,
          local: _vault([
            _entry(
              'a',
              'Banco',
              modifiedAt: DateTime.utc(2026, 2),
              fields: {}, // vació las notas
            ),
          ]),
          remote: _vault([
            _entry(
              'a',
              'Banco editada',
              modifiedAt: DateTime.utc(2026, 3),
              fields: {'notes': 'algo'}, // no tocó las notas
            ),
          ]),
        );

        final result = analysis.autoMerged.entries.single;
        expect(result.fields.containsKey('notes'), isFalse);
        expect(result.title, 'Banco editada');
      });

      test(
        'sin ancestro: campos distintos con el mismo id se combinan igual '
        '(Nivel 1) y un choque real de campo se resuelve igual (Nivel 2)',
        () {
          final analysis = mergeVaults(
            ancestor: null,
            local: _vault([
              _entry(
                'a',
                'Banco',
                modifiedAt: DateTime.utc(2026, 2, 1, 9),
                fields: {'username': 'u', 'password': 'de-local'},
              ),
            ]),
            remote: _vault([
              _entry(
                'a',
                'Banco',
                modifiedAt: DateTime.utc(2026, 2, 1, 10),
                fields: {'username': 'u', 'password': 'de-remoto'},
              ),
            ]),
          );

          expect(analysis.fieldConflictsResolved, 1);
          final result = analysis.autoMerged.entries.single;
          expect(result.fields['username'], 'u'); // no fue conflicto
          expect(result.fields['password'], 'de-remoto'); // ganó el más nuevo
        },
      );

      test('el historial se deduplica por valor antes de aplicar el tope, y '
          'nunca crece más allá de maxFieldHistoryPerField', () {
        var ancestor = _vault([
          _entry('a', 'Banco', fields: {'password': 'v0'}),
        ]);
        var t = DateTime.utc(2026, 1, 1);

        // 5 rondas de conflicto real sobre el mismo campo — cada local y
        // remoto parten del resultado ya mergeado de la ronda anterior
        // (mismo `copyWith` que usaría un editor real, conserva el
        // fieldHistory acumulado) — debería agregar un valor nuevo al
        // historial por ronda, nunca más de maxFieldHistoryPerField.
        for (var i = 1; i <= 5; i++) {
          t = t.add(const Duration(days: 1));
          final base = ancestor.entries.single;
          final local = base.copyWith(
            modifiedAt: t,
            fields: {'password': 'local-$i'},
          );
          final remote = base.copyWith(
            modifiedAt: t.add(const Duration(hours: 1)), // remoto siempre gana
            fields: {'password': 'remota-$i'},
          );
          final analysis = mergeVaults(
            ancestor: ancestor,
            local: _vault([local]),
            remote: _vault([remote]),
          );
          ancestor = analysis.autoMerged;
        }

        final history = ancestor.entries.single.fieldHistory['password']!;
        expect(history.length, maxFieldHistoryPerField);
        expect(history.map((r) => r.value).toSet().length, history.length);
      });

      test('el atajo de "ambos lados ya coinciden" no combina fieldHistory — '
          'decisión explícita (ADR 0009, punto 4), no un descuido', () {
        final localHistory = {
          'password': [
            FieldHistoryRecord(
              value: 'vieja-local',
              replacedAt: DateTime.utc(2026, 1, 1),
            ),
          ],
        };
        final ancestor = _vault([
          _entry('a', 'Banco', fields: {'password': 'actual'}),
        ]);
        final analysis = mergeVaults(
          ancestor: ancestor,
          local: _vault([
            _entry(
              'a',
              'Banco',
              modifiedAt: DateTime.utc(2026, 2),
              fields: {'password': 'actual'},
              fieldHistory: localHistory,
            ),
          ]),
          remote: _vault([
            _entry(
              'a',
              'Banco',
              modifiedAt: DateTime.utc(2026, 2),
              fields: {'password': 'actual'},
            ),
          ]),
        );

        // Contenido real idéntico → toma el atajo _sameContent, conserva
        // el local tal cual (con su historial), no fusiona con remoto.
        expect(
          analysis.autoMerged.entries.single.fieldHistory['password'],
          localHistory['password'],
        );
      });

      test('el orden de las entradas no cambia el resultado', () {
        final ancestor = _vault([
          _entry('a', 'A', fields: {'x': '1'}),
          _entry('b', 'B', fields: {'x': '1'}),
        ]);
        final local = _vault([
          _entry(
            'a',
            'A',
            modifiedAt: DateTime.utc(2026, 2),
            fields: {'x': '2'},
          ),
          _entry(
            'b',
            'B',
            modifiedAt: DateTime.utc(2026, 2, 1, 9),
            fields: {'x': '2'},
          ),
        ]);
        final remote = _vault([
          _entry(
            'b',
            'B',
            modifiedAt: DateTime.utc(2026, 2, 1, 10),
            fields: {'x': '3'},
          ),
          _entry(
            'a',
            'A',
            modifiedAt: DateTime.utc(2026, 2),
            fields: {'x': '2'},
          ),
        ]);

        final analysis1 = mergeVaults(
          ancestor: ancestor,
          local: local,
          remote: remote,
        );
        final analysis2 = mergeVaults(
          ancestor: _vault(ancestor.entries.reversed.toList()),
          local: _vault(local.entries.reversed.toList()),
          remote: remote,
        );

        expect(
          analysis1.fieldConflictsResolved,
          analysis2.fieldConflictsResolved,
        );
        expect(
          analysis1.autoMerged.entries.map((e) => e.id).toSet(),
          analysis2.autoMerged.entries.map((e) => e.id).toSet(),
        );
        expect(
          analysis1.autoMerged.entries
              .firstWhere((e) => e.id == 'b')
              .fields['x'],
          analysis2.autoMerged.entries
              .firstWhere((e) => e.id == 'b')
              .fields['x'],
        );
      });
    },
  );
}
