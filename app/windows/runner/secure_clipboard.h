// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

#ifndef RUNNER_SECURE_CLIPBOARD_H_
#define RUNNER_SECURE_CLIPBOARD_H_

#include <windows.h>

#include <optional>
#include <string>

// Portapapeles para secretos (revisión 2026-09-25, hallazgo S4). Ver
// lib/features/clipboard/infrastructure/windows_secure_clipboard_adapter.dart.
namespace secure_clipboard {

// Copia |utf8_text| marcado para que Windows no lo guarde en el historial
// (Win+V) ni lo suba al portapapeles en la nube, y para que las apps que
// vigilan el portapapeles lo ignoren. Devuelve el número de secuencia del
// portapapeles tras copiar, o nullopt si no se pudo.
std::optional<DWORD> CopySensitiveText(HWND owner, const std::string& utf8_text);

// Vacía el portapapeles solo si sigue teniendo lo que se copió con
// |sequence| (nadie copió otra cosa después). Devuelve true si lo vació.
bool ClearIfUnchanged(HWND owner, DWORD sequence);

}  // namespace secure_clipboard

#endif  // RUNNER_SECURE_CLIPBOARD_H_
