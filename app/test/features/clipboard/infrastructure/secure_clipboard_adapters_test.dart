// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/clipboard/infrastructure/android_secure_clipboard_adapter.dart';
import 'package:lockspire/features/clipboard/infrastructure/flutter_secure_clipboard_adapter.dart';
import 'package:lockspire/features/clipboard/infrastructure/windows_secure_clipboard_adapter.dart';

const _clearAfter = Duration(seconds: 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('WindowsSecureClipboardAdapter (S4)', () {
    const channel = MethodChannel('com.lockspire.lockspire/clipboard');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'copySensitive' ? 4242 : true;
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('borra con la secuencia que devolvió la copia', () async {
      final adapter = WindowsSecureClipboardAdapter();
      await adapter.copySensitive('secreto', clearAfter: _clearAfter);
      await adapter.clearIfStillOurs();

      expect(calls.map((c) => c.method), ['copySensitive', 'clearIfUnchanged']);
      expect(calls.first.arguments, 'secreto');
      expect(calls.last.arguments, 4242);
    });

    test('sin copia previa, o ya borrada, no llama al nativo', () async {
      final adapter = WindowsSecureClipboardAdapter();
      await adapter.clearIfStillOurs();
      await adapter.copySensitive('secreto', clearAfter: _clearAfter);
      await adapter.clearIfStillOurs();
      await adapter.clearIfStillOurs();

      expect(calls.where((c) => c.method == 'clearIfUnchanged'), hasLength(1));
    });
  });

  group('AndroidSecureClipboardAdapter (S4)', () {
    const channel = MethodChannel('com.lockspire.lockspire/clipboard');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'clearIfOurs' ? true : null;
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('envía el plazo para que el sistema programe el borrado', () async {
      await AndroidSecureClipboardAdapter().copySensitive(
        'secreto',
        clearAfter: _clearAfter,
      );
      expect(calls.single.method, 'copySensitive');
      expect(calls.single.arguments, {
        'text': 'secreto',
        'clearAfterMs': 30000,
      });
    });
  });

  group('FlutterSecureClipboardAdapter (S4)', () {
    String? clipboardText;

    setUp(() {
      clipboardText = null;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboardText = (call.arguments as Map)['text'] as String?;
            return null;
          case 'Clipboard.getData':
            return {'text': clipboardText};
        }
        return null;
      });
    });

    tearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    test('borra si sigue estando lo copiado', () async {
      final adapter = FlutterSecureClipboardAdapter();
      await adapter.copySensitive('secreto', clearAfter: _clearAfter);
      await adapter.clearIfStillOurs();
      expect(clipboardText, '');
    });

    test('no pisa algo que el usuario copió después', () async {
      final adapter = FlutterSecureClipboardAdapter();
      await adapter.copySensitive('secreto', clearAfter: _clearAfter);
      clipboardText = 'otra cosa';
      await adapter.clearIfStillOurs();
      expect(clipboardText, 'otra cosa');
    });
  });
}
