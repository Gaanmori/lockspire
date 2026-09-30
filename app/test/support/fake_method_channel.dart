// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// El lado nativo de un canal (Kotlin, C++ o un plugin), en memoria: anota
/// lo que pide Dart, contesta con [answers] y puede llamar a Dart como lo
/// haría la plataforma ([emit]). Se desmonta solo al terminar el test.
class FakeMethodChannel {
  final MethodChannel channel;

  /// Qué pidió Dart, en orden.
  final calls = <MethodCall>[];

  /// Respuesta por método: un valor, o una función que recibe los
  /// argumentos. Lanzar [PlatformException] desde la función simula un
  /// error nativo. Un método sin entrada contesta `null`.
  final answers = <String, Object? Function(Object? arguments)>{};

  FakeMethodChannel(String name) : channel = MethodChannel(name) {
    _messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answers[call.method]?.call(call.arguments);
    });
    addTearDown(() => _messenger.setMockMethodCallHandler(channel, null));
  }

  static TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Contesta siempre [value] a [method].
  void answer(String method, Object? value) => answers[method] = (_) => value;

  /// Contesta a [method] con un error nativo.
  void fail(String method) =>
      answers[method] = (_) =>
          throw PlatformException(code: 'ERROR', message: 'falló en nativo');

  /// Los nombres de los métodos pedidos, en orden.
  List<String> get methods => [for (final c in calls) c.method];

  /// Los argumentos de la última llamada a [method].
  Object? argumentsOf(String method) =>
      calls.lastWhere((c) => c.method == method).arguments;

  /// La plataforma llama a Dart.
  Future<void> emit(String method, [Object? arguments]) async {
    await _messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
  }
}
