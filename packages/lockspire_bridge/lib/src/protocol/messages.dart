// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'protocol_exception.dart';

/// Versión del protocolo (campo `v` de cada mensaje, ADR 0013).
const protocolVersion = 1;

const minGeneratedLength = 16;
const maxGeneratedLength = 64;

/// Largo máximo de un usuario o una contraseña que manda la extensión al
/// ofrecer guardarla (ADR 0034).
const maxLoginFieldLength = 1024;

final _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _entryIdPattern = RegExp(r'^[A-Za-z0-9-]{1,64}$');
// Exactamente lo que produce `new URL(...).origin` para http/https:
// esquema + host (+ puerto). Sin ruta, query, fragmento, userinfo ni
// espacios. IPv6 entre corchetes permitido.
final _originPattern = RegExp(
  r'^https?://(\[[0-9a-f:.]+\]|[a-z0-9.-]+)(:[0-9]{1,5})?$',
);
final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
final _callerPattern = RegExp(r'^chrome-extension://[a-p]{32}/$');

/// Tipos de mensaje. Los nombres son los literales del campo `type`.
abstract final class MessageType {
  // Handshake IPC (host/app-instance → app).
  static const hello = 'HELLO';
  static const helloOk = 'HELLO_OK';

  // Peticiones (extensión → app).
  static const ping = 'PING';
  static const getCredentialsForOrigin = 'GET_CREDENTIALS_FOR_ORIGIN';
  static const getCredentialSecret = 'GET_CREDENTIAL_SECRET';
  static const generatePassword = 'GENERATE_PASSWORD';
  static const showApp = 'SHOW_APP';
  static const listCredentials = 'LIST_CREDENTIALS';
  static const requestLinkOrigin = 'REQUEST_LINK_ORIGIN';
  static const checkLogin = 'CHECK_LOGIN';
  static const saveLogin = 'SAVE_LOGIN';
  static const neverSaveForOrigin = 'NEVER_SAVE_FOR_ORIGIN';

  // Respuestas (app → extensión).
  static const pong = 'PONG';
  static const credentials = 'CREDENTIALS';
  static const credentialSecret = 'CREDENTIAL_SECRET';
  static const generatedPassword = 'GENERATED_PASSWORD';
  static const loginStatus = 'LOGIN_STATUS';
  static const ok = 'OK';
  static const unlockRequired = 'UNLOCK_REQUIRED';
  static const error = 'ERROR';
}

/// Códigos de `ERROR`.
abstract final class ErrorCode {
  static const badRequest = 'BAD_REQUEST';
  static const notFound = 'NOT_FOUND';
  static const appNotRunning = 'APP_NOT_RUNNING';
  static const internal = 'INTERNAL';
}

/// Quién abre la conexión IPC.
enum ClientKind {
  /// El native host, lanzado por el navegador.
  nativeHost('native-host'),

  /// Una segunda instancia de la app pidiendo a la primera que se muestre
  /// (instancia única, ADR 0012).
  appInstance('app-instance');

  final String wire;
  const ClientKind(this.wire);
}

// ---------------------------------------------------------------------
// Handshake
// ---------------------------------------------------------------------

class HelloMessage {
  final String token;
  final ClientKind client;

  /// `chrome-extension://<id>/` que lanzó al host (lo pasa Chrome como
  /// primer argumento). `null` para [ClientKind.appInstance].
  final String? caller;

  const HelloMessage({required this.token, required this.client, this.caller});

  Map<String, Object?> toJson() => {
    'v': protocolVersion,
    'type': MessageType.hello,
    'token': token,
    'client': client.wire,
    'caller': ?caller,
  };

  static HelloMessage parse(Map<String, Object?> json) {
    _expectKeys(
      json,
      required: {'v', 'type', 'token', 'client'},
      optional: {'caller'},
    );
    _expectVersion(json);
    if (json['type'] != MessageType.hello) {
      throw const BridgeProtocolException('se esperaba HELLO');
    }
    final token = _string(json, 'token');
    if (!_tokenPattern.hasMatch(token)) {
      throw const BridgeProtocolException('token con formato inválido');
    }
    final clientWire = _string(json, 'client');
    final client = ClientKind.values
        .where((c) => c.wire == clientWire)
        .firstOrNull;
    if (client == null) {
      throw const BridgeProtocolException('client desconocido');
    }
    final caller = json.containsKey('caller') ? _string(json, 'caller') : null;
    if (client == ClientKind.nativeHost &&
        (caller == null || !_callerPattern.hasMatch(caller))) {
      throw const BridgeProtocolException('caller inválido');
    }
    if (client == ClientKind.appInstance && caller != null) {
      throw const BridgeProtocolException('caller no permitido');
    }
    return HelloMessage(token: token, client: client, caller: caller);
  }
}

Map<String, Object?> helloOk() => {
  'v': protocolVersion,
  'type': MessageType.helloOk,
};

/// Valida la respuesta al `HELLO`.
void expectHelloOk(Map<String, Object?> json) {
  _expectKeys(json, required: {'v', 'type'});
  _expectVersion(json);
  if (json['type'] != MessageType.helloOk) {
    throw const BridgeProtocolException('handshake rechazado');
  }
}

// ---------------------------------------------------------------------
// Peticiones
// ---------------------------------------------------------------------

sealed class BridgeRequest {
  final String id;
  const BridgeRequest(this.id);

  String get type;

  Map<String, Object?> toJson() => {
    'v': protocolVersion,
    'id': id,
    'type': type,
    ..._fields(),
  };

  Map<String, Object?> _fields();

  /// Parsea y valida estrictamente una petición. Cualquier desviación del
  /// esquema lanza [BridgeProtocolException].
  static BridgeRequest parse(Map<String, Object?> json) {
    final type = json['type'];
    if (type is! String) {
      throw const BridgeProtocolException('type ausente');
    }
    switch (type) {
      case MessageType.ping:
        _expectKeys(json, required: {'v', 'id', 'type'});
        _expectVersion(json);
        return PingRequest(_id(json));
      case MessageType.getCredentialsForOrigin:
        _expectKeys(json, required: {'v', 'id', 'type', 'origin'});
        _expectVersion(json);
        return GetCredentialsRequest(_id(json), origin: _origin(json));
      case MessageType.getCredentialSecret:
        _expectKeys(json, required: {'v', 'id', 'type', 'origin', 'entry_id'});
        _expectVersion(json);
        return GetCredentialSecretRequest(
          _id(json),
          origin: _origin(json),
          entryId: _entryId(json),
        );
      case MessageType.generatePassword:
        _expectKeys(json, required: {'v', 'id', 'type', 'length'});
        _expectVersion(json);
        final length = json['length'];
        if (length is! int ||
            length < minGeneratedLength ||
            length > maxGeneratedLength) {
          throw const BridgeProtocolException('length fuera de rango');
        }
        return GeneratePasswordRequest(_id(json), length: length);
      case MessageType.showApp:
        _expectKeys(json, required: {'v', 'id', 'type'});
        _expectVersion(json);
        return ShowAppRequest(_id(json));
      case MessageType.listCredentials:
        _expectKeys(json, required: {'v', 'id', 'type'});
        _expectVersion(json);
        return ListCredentialsRequest(_id(json));
      case MessageType.requestLinkOrigin:
        _expectKeys(json, required: {'v', 'id', 'type', 'origin', 'entry_id'});
        _expectVersion(json);
        return RequestLinkOriginRequest(
          _id(json),
          origin: _origin(json),
          entryId: _entryId(json),
        );
      case MessageType.checkLogin || MessageType.saveLogin:
        _expectKeys(
          json,
          required: {'v', 'id', 'type', 'origin', 'username', 'password'},
        );
        _expectVersion(json);
        final login = (
          origin: _origin(json),
          username: _loginField(json, 'username'),
          password: _loginField(json, 'password'),
        );
        if (login.password.isEmpty) {
          throw const BridgeProtocolException('password vacío');
        }
        return type == MessageType.checkLogin
            ? CheckLoginRequest(
                _id(json),
                origin: login.origin,
                username: login.username,
                password: login.password,
              )
            : SaveLoginRequest(
                _id(json),
                origin: login.origin,
                username: login.username,
                password: login.password,
              );
      case MessageType.neverSaveForOrigin:
        _expectKeys(json, required: {'v', 'id', 'type', 'origin'});
        _expectVersion(json);
        return NeverSaveForOriginRequest(_id(json), origin: _origin(json));
      default:
        throw const BridgeProtocolException('type desconocido');
    }
  }

  /// Extrae el `id` de un mensaje que no pasó la validación, para poder
  /// correlacionar el `ERROR` — solo si tiene el formato correcto.
  static String? tryExtractId(Map<String, Object?> json) {
    final id = json['id'];
    return id is String && _idPattern.hasMatch(id) ? id : null;
  }
}

class PingRequest extends BridgeRequest {
  const PingRequest(super.id);
  @override
  String get type => MessageType.ping;
  @override
  Map<String, Object?> _fields() => const {};
}

class GetCredentialsRequest extends BridgeRequest {
  final String origin;
  const GetCredentialsRequest(super.id, {required this.origin});
  @override
  String get type => MessageType.getCredentialsForOrigin;
  @override
  Map<String, Object?> _fields() => {'origin': origin};
}

class GetCredentialSecretRequest extends BridgeRequest {
  final String origin;
  final String entryId;
  const GetCredentialSecretRequest(
    super.id, {
    required this.origin,
    required this.entryId,
  });
  @override
  String get type => MessageType.getCredentialSecret;
  @override
  Map<String, Object?> _fields() => {'origin': origin, 'entry_id': entryId};
}

class GeneratePasswordRequest extends BridgeRequest {
  final int length;
  const GeneratePasswordRequest(super.id, {required this.length});
  @override
  String get type => MessageType.generatePassword;
  @override
  Map<String, Object?> _fields() => {'length': length};
}

class ShowAppRequest extends BridgeRequest {
  const ShowAppRequest(super.id);
  @override
  String get type => MessageType.showApp;
  @override
  Map<String, Object?> _fields() => const {};
}

/// Todas las entradas de contraseña (resumen sin contraseñas), para elegir
/// una a mano cuando ninguna coincide con el sitio (ADR 0015).
class ListCredentialsRequest extends BridgeRequest {
  const ListCredentialsRequest(super.id);
  @override
  String get type => MessageType.listCredentials;
  @override
  Map<String, Object?> _fields() => const {};
}

/// Pide vincular [origin] a una entrada. La app **no** lo aplica: muestra
/// una confirmación en su propia ventana y responde `OK` de inmediato
/// (ADR 0015).
class RequestLinkOriginRequest extends BridgeRequest {
  final String origin;
  final String entryId;
  const RequestLinkOriginRequest(
    super.id, {
    required this.origin,
    required this.entryId,
  });
  @override
  String get type => MessageType.requestLinkOrigin;
  @override
  Map<String, Object?> _fields() => {'origin': origin, 'entry_id': entryId};
}

/// Un inicio de sesión que la extensión vio enviar en [origin] (ADR 0034).
sealed class LoginRequest extends BridgeRequest {
  final String origin;
  final String username;
  final String password;
  const LoginRequest(
    super.id, {
    required this.origin,
    required this.username,
    required this.password,
  });
  @override
  Map<String, Object?> _fields() => {
    'origin': origin,
    'username': username,
    'password': password,
  };
}

/// ¿Hay que ofrecer guardar este inicio de sesión? Responde
/// `LOGIN_STATUS`, o `UNLOCK_REQUIRED` con la bóveda bloqueada. No cambia
/// nada.
class CheckLoginRequest extends LoginRequest {
  const CheckLoginRequest(
    super.id, {
    required super.origin,
    required super.username,
    required super.password,
  });
  @override
  String get type => MessageType.checkLogin;
}

/// El usuario eligió "Guardar" en el aviso de la página. Con la bóveda
/// bloqueada, la app lo guarda al desbloquear y responde `UNLOCK_REQUIRED`.
class SaveLoginRequest extends LoginRequest {
  const SaveLoginRequest(
    super.id, {
    required super.origin,
    required super.username,
    required super.password,
  });
  @override
  String get type => MessageType.saveLogin;
}

/// "No volver a preguntar en este sitio".
class NeverSaveForOriginRequest extends BridgeRequest {
  final String origin;
  const NeverSaveForOriginRequest(super.id, {required this.origin});
  @override
  String get type => MessageType.neverSaveForOrigin;
  @override
  Map<String, Object?> _fields() => {'origin': origin};
}

// ---------------------------------------------------------------------
// Respuestas
// ---------------------------------------------------------------------

/// Qué hacer con un inicio de sesión recién enviado (ADR 0034).
enum LoginStatus {
  /// No está en la bóveda: ofrecer guardarlo.
  newLogin('new'),

  /// Hay una entrada del sitio con ese usuario y otra contraseña: ofrecer
  /// actualizarla.
  update('update'),

  /// Ya está guardado tal cual: no preguntar.
  saved('saved'),

  /// El usuario pidió no preguntar en este sitio.
  never('never');

  final String wire;
  const LoginStatus(this.wire);
}

/// Resumen de una credencial para el popup — sin contraseña (ADR 0013).
class CredentialSummary {
  final String entryId;
  final String title;
  final String username;

  const CredentialSummary({
    required this.entryId,
    required this.title,
    required this.username,
  });

  Map<String, Object?> toJson() => {
    'entry_id': entryId,
    'title': title,
    'username': username,
  };
}

Map<String, Object?> _response(
  String id,
  String type, [
  Map<String, Object?> fields = const {},
]) => {'v': protocolVersion, 'id': id, 'type': type, ...fields};

/// [themeFamily] (`lineage`/`pixel`/`calido`/`menta`/`lavanda`) y [themeMode]
/// (`system`/`light`/`dark`) le dicen a la extensión con qué tema pintarse
/// para que coincida con la app. Opcionales: una app sin preferencia de
/// tema no los envía.
Map<String, Object?> pongResponse(
  String id, {
  required bool locked,
  String? themeFamily,
  String? themeMode,
  String? language,
}) => _response(id, MessageType.pong, {
  'locked': locked,
  if (themeFamily != null && themeMode != null)
    'theme': {'family': themeFamily, 'mode': themeMode},
  // Idioma de la app ("es", "en"), para que la extensión use el mismo
  // (ADR 0032). Opcional: una extensión vieja lo ignora.
  'lang': ?language,
});

Map<String, Object?> credentialsResponse(
  String id,
  List<CredentialSummary> entries,
) => _response(id, MessageType.credentials, {
  'entries': [for (final e in entries) e.toJson()],
});

Map<String, Object?> credentialSecretResponse(
  String id, {
  required String username,
  required String password,
}) => _response(id, MessageType.credentialSecret, {
  'username': username,
  'password': password,
});

Map<String, Object?> generatedPasswordResponse(String id, String password) =>
    _response(id, MessageType.generatedPassword, {'password': password});

/// [title]: la entrada que se actualizaría, solo con [LoginStatus.update].
Map<String, Object?> loginStatusResponse(
  String id,
  LoginStatus status, {
  String? title,
}) => _response(id, MessageType.loginStatus, {
  'status': status.wire,
  'title': ?title,
});

Map<String, Object?> okResponse(String id) => _response(id, MessageType.ok);

Map<String, Object?> unlockRequiredResponse(String id) =>
    _response(id, MessageType.unlockRequired);

/// `id` puede ser `null` si la petición era tan inválida que ni siquiera
/// tenía un `id` utilizable.
Map<String, Object?> errorResponse(String? id, String code) => {
  'v': protocolVersion,
  'id': ?id,
  'type': MessageType.error,
  'code': code,
};

/// Comprobación mínima de una respuesta de la app antes de que el host la
/// reenvíe al navegador: envoltorio correcto y `id` correlacionado. El
/// contenido lo valida la extensión.
void expectResponseEnvelope(
  Map<String, Object?> json, {
  required String requestId,
}) {
  if (json['v'] != protocolVersion) {
    throw const BridgeProtocolException('versión de protocolo no soportada');
  }
  if (json['type'] is! String) {
    throw const BridgeProtocolException('type ausente');
  }
  if (json['id'] != requestId) {
    throw const BridgeProtocolException('id de respuesta no correlaciona');
  }
}

// ---------------------------------------------------------------------
// Helpers de validación
// ---------------------------------------------------------------------

void _expectKeys(
  Map<String, Object?> json, {
  required Set<String> required,
  Set<String> optional = const {},
}) {
  for (final key in required) {
    if (!json.containsKey(key)) {
      throw BridgeProtocolException('falta "$key"');
    }
  }
  for (final key in json.keys) {
    if (!required.contains(key) && !optional.contains(key)) {
      throw BridgeProtocolException('clave no permitida "$key"');
    }
  }
}

void _expectVersion(Map<String, Object?> json) {
  if (json['v'] != protocolVersion) {
    throw const BridgeProtocolException('versión de protocolo no soportada');
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw BridgeProtocolException('"$key" debe ser texto');
  }
  return value;
}

String _id(Map<String, Object?> json) {
  final id = _string(json, 'id');
  if (!_idPattern.hasMatch(id)) {
    throw const BridgeProtocolException('id inválido');
  }
  return id;
}

String _entryId(Map<String, Object?> json) {
  final entryId = _string(json, 'entry_id');
  if (!_entryIdPattern.hasMatch(entryId)) {
    throw const BridgeProtocolException('entry_id inválido');
  }
  return entryId;
}

String _loginField(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  if (value.length > maxLoginFieldLength) {
    throw BridgeProtocolException('"$key" demasiado largo');
  }
  return value;
}

String _origin(Map<String, Object?> json) {
  final origin = _string(json, 'origin');
  if (origin.length > 2048 || !_originPattern.hasMatch(origin)) {
    throw const BridgeProtocolException('origin inválido');
  }
  return origin;
}
