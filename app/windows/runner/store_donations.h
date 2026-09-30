// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

#ifndef RUNNER_STORE_DONATIONS_H_
#define RUNNER_STORE_DONATIONS_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <functional>
#include <memory>

// Donaciones con los complementos de Microsoft Store (ADR 0035), canal
// `com.lockspire.lockspire/store_donations`. Delgado a propósito: lista los
// complementos consumibles, abre la compra con el diálogo de la Store y
// confirma lo comprado. Qué ofrecer y qué mostrar lo decide Dart
// (lib/features/about/infrastructure/microsoft_store_donation_adapter.dart).
namespace store_donations {

// Pone |task| en la cola del hilo de la interfaz: las respuestas a Dart
// deben salir de ese hilo, y la Store responde desde otro.
using RunOnUi = std::function<void(std::function<void()>)>;

class StoreDonationsChannel {
 public:
  StoreDonationsChannel(flutter::BinaryMessenger* messenger, HWND window,
                        RunOnUi run_on_ui);
  ~StoreDonationsChannel();

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  RunOnUi run_on_ui_;
};

}  // namespace store_donations

#endif  // RUNNER_STORE_DONATIONS_H_
