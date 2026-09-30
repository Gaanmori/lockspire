#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <deque>
#include <functional>
#include <memory>
#include <mutex>

#include "store_donations.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Reenvía a Dart un evento de sesión del SO (ADR 0012): la bóveda se
  // bloquea al bloquear la sesión o antes de suspender el equipo.
  void NotifyOsSessionEvent(const char* method);

  // Corre |task| en el hilo de la interfaz, desde cualquier hilo (ver
  // store_donations.h).
  void RunOnUi(std::function<void()> task);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Canal `com.lockspire/os_session` (ver
  // lib/features/desktop/infrastructure/windows_os_session_events_adapter.dart).
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      os_session_channel_;

  // Canal `com.lockspire.lockspire/clipboard` (hallazgo S4, ver
  // lib/features/clipboard/infrastructure/windows_secure_clipboard_adapter.dart).
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      clipboard_channel_;

  // Canal `com.lockspire.lockspire/store_donations` (ADR 0035).
  std::unique_ptr<store_donations::StoreDonationsChannel> store_donations_;

  std::mutex ui_tasks_mutex_;
  std::deque<std::function<void()>> ui_tasks_;

  bool session_notifications_registered_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
