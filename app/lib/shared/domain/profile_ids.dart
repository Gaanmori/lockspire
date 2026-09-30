// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Id del perfil que ya existía antes de los perfiles (ADR 0039): conserva
/// la ruta de su bóveda y sus claves sin prefijo.
const mainProfileId = 'principal';

final _validId = RegExp(r'^[A-Za-z0-9-]{1,64}$');

/// Si [id] puede ser el id de un perfil. Los ids van en rutas de archivos
/// (`profiles/<id>/`) y en claves del almacenamiento seguro: solo letras,
/// dígitos y guiones, así un id manipulado (`../..`) nunca apunta fuera de
/// su carpeta.
bool isValidProfileId(String id) => _validId.hasMatch(id);

/// Lanza [ArgumentError] si [id] no es un id de perfil válido.
String checkProfileId(String id) {
  if (!isValidProfileId(id)) {
    throw ArgumentError.value(id, 'id', 'no es un id de perfil válido');
  }
  return id;
}
