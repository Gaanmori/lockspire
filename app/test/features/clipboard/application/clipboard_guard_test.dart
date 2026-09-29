// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/clipboard/application/clipboard_guard.dart';
import 'package:lockspire/features/clipboard/domain/ports/secure_clipboard_port.dart';

class _FakeClipboard implements SecureClipboardPort {
  final copies = <String>[];
  int clears = 0;
  bool failClear = false;
  final delays = <Duration>[];

  @override
  Future<void> copySensitive(
    String text, {
    required Duration clearAfter,
  }) async {
    copies.add(text);
    delays.add(clearAfter);
  }

  @override
  Future<void> clearIfStillOurs() async {
    clears++;
    if (failClear) throw StateError('sin portapapeles');
  }
}

void main() {
  late _FakeClipboard clipboard;
  late ClipboardGuard guard;

  setUp(() {
    clipboard = _FakeClipboard();
    guard = ClipboardGuard(port: clipboard);
  });

  group('ClipboardGuard (S4)', () {
    test('copia como sensible y borra a los 30 s', () {
      fakeAsync((async) {
        guard.copy('secreto');
        async.flushMicrotasks();
        expect(clipboard.copies, ['secreto']);

        async.elapse(const Duration(seconds: 29));
        expect(clipboard.clears, 0);
        async.elapse(const Duration(seconds: 1));
        expect(clipboard.clears, 1);
      });
    });

    test('una copia nueva reinicia el plazo', () {
      fakeAsync((async) {
        guard.copy('usuario');
        async.elapse(const Duration(seconds: 20));
        guard.copy('contraseña');
        async.elapse(const Duration(seconds: 20));
        expect(clipboard.clears, 0);
        async.elapse(const Duration(seconds: 10));
        expect(clipboard.clears, 1);
      });
    });

    test('clearNow borra ya y cancela el temporizador', () {
      fakeAsync((async) {
        guard.copy('secreto');
        async.flushMicrotasks();
        guard.clearNow();
        async.flushMicrotasks();
        expect(clipboard.clears, 1);
        async.elapse(const Duration(minutes: 1));
        expect(clipboard.clears, 1);
      });
    });

    test('sin nada copiado, clearNow no toca el portapapeles', () async {
      await guard.clearNow();
      expect(clipboard.clears, 0);
    });

    test('llamar dos veces devuelve el mismo borrado en curso', () async {
      await guard.copy('secreto');
      final first = guard.clearNow();
      final second = guard.clearNow();
      await Future.wait([first, second]);
      expect(clipboard.clears, 1);
    });

    test(
      'pasa el plazo al adaptador (Android lo programa en el sistema)',
      () async {
        await guard.copy('secreto');
        expect(clipboard.delays, [defaultClipboardClearAfter]);
      },
    );

    test('si el plazo venció, al volver a la app se repite el borrado '
        '(HyperOS descarta el de segundo plano)', () {
      fakeAsync((async) {
        guard.copy('secreto');
        async.elapse(const Duration(seconds: 30));
        expect(clipboard.clears, 1);

        guard.onResumed();
        async.flushMicrotasks();
        expect(clipboard.clears, 2);

        guard.onResumed();
        async.flushMicrotasks();
        expect(clipboard.clears, 2, reason: 'solo se repite una vez');
      });
    });

    test('volver a la app antes del plazo no borra nada', () {
      fakeAsync((async) {
        guard.copy('secreto');
        async.elapse(const Duration(seconds: 10));
        guard.onResumed();
        async.flushMicrotasks();
        expect(clipboard.clears, 0);
      });
    });

    test('no copia textos vacíos', () async {
      await guard.copy('');
      expect(clipboard.copies, isEmpty);
    });

    test('un fallo al borrar nunca se propaga', () async {
      clipboard.failClear = true;
      await guard.copy('secreto');
      await expectLater(guard.clearNow(), completes);
    });
  });
}
