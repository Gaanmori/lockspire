// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

#include "secure_clipboard.h"

#include <cstring>

namespace secure_clipboard {
namespace {

// Otra app puede tener el portapapeles abierto un instante.
bool OpenWithRetry(HWND owner) {
  for (int attempt = 0; attempt < 10; ++attempt) {
    if (OpenClipboard(owner)) return true;
    Sleep(20);
  }
  return false;
}

// Coloca |size| bytes de |data| en el formato |format|. El sistema pasa a
// ser dueño de la memoria solo si SetClipboardData tiene éxito.
bool SetBytes(UINT format, const void* data, size_t size) {
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, size);
  if (!memory) return false;
  void* target = GlobalLock(memory);
  if (!target) {
    GlobalFree(memory);
    return false;
  }
  std::memcpy(target, data, size);
  GlobalUnlock(memory);
  if (!SetClipboardData(format, memory)) {
    GlobalFree(memory);
    return false;
  }
  return true;
}

bool SetDword(const wchar_t* format_name, DWORD value) {
  UINT format = RegisterClipboardFormatW(format_name);
  return format != 0 && SetBytes(format, &value, sizeof(value));
}

}  // namespace

std::optional<DWORD> CopySensitiveText(HWND owner,
                                       const std::string& utf8_text) {
  int wide_len = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                     utf8_text.data(),
                                     static_cast<int>(utf8_text.size()),
                                     nullptr, 0);
  if (wide_len <= 0 && !utf8_text.empty()) return std::nullopt;
  std::wstring wide(static_cast<size_t>(wide_len), L'\0');
  if (wide_len > 0) {
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_text.data(),
                        static_cast<int>(utf8_text.size()), wide.data(),
                        wide_len);
  }

  if (!OpenWithRetry(owner)) return std::nullopt;
  bool ok = EmptyClipboard() &&
            // Formatos documentados por Microsoft para contenido sensible:
            // fuera del historial, fuera de la nube y fuera de los
            // monitores de portapapeles. Se colocan antes del texto.
            SetDword(L"ExcludeClipboardContentFromMonitorProcessing", 0) &&
            SetDword(L"CanIncludeInClipboardHistory", 0) &&
            SetDword(L"CanUploadToCloudClipboard", 0) &&
            SetBytes(CF_UNICODETEXT, wide.c_str(),
                     (wide.size() + 1) * sizeof(wchar_t));
  if (!ok) EmptyClipboard();
  CloseClipboard();
  SecureZeroMemory(wide.data(), wide.size() * sizeof(wchar_t));
  if (!ok) return std::nullopt;
  return GetClipboardSequenceNumber();
}

bool ClearIfUnchanged(HWND owner, DWORD sequence) {
  if (GetClipboardSequenceNumber() != sequence) return false;
  if (!OpenWithRetry(owner)) return false;
  // Se vuelve a mirar con el portapapeles ya abierto: nadie puede
  // cambiarlo entre la comprobación y el vaciado.
  bool cleared = GetClipboardSequenceNumber() == sequence && EmptyClipboard();
  CloseClipboard();
  return cleared;
}

}  // namespace secure_clipboard
