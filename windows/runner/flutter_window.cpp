#include "flutter_window.h"

#include <cmath>
#include <optional>
#include <windows.h>
#include <winuser.h>

#include <memory>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr double kWindowAspectRatio = 16.0 / 9.0;

void KeepWindowAspectRatio(WPARAM edge, RECT* rect) {
  if (!rect) {
    return;
  }

  const LONG width = rect->right - rect->left;
  const LONG height = rect->bottom - rect->top;
  const LONG height_from_width =
      static_cast<LONG>(std::lround(width / kWindowAspectRatio));
  const LONG width_from_height =
      static_cast<LONG>(std::lround(height * kWindowAspectRatio));

  switch (edge) {
    case WMSZ_LEFT:
    case WMSZ_RIGHT:
      rect->bottom = rect->top + height_from_width;
      break;
    case WMSZ_TOP:
    case WMSZ_BOTTOM:
      rect->right = rect->left + width_from_height;
      break;
    case WMSZ_TOPLEFT:
      if (width > width_from_height) {
        rect->top = rect->bottom - height_from_width;
      } else {
        rect->left = rect->right - width_from_height;
      }
      break;
    case WMSZ_TOPRIGHT:
      if (width > width_from_height) {
        rect->top = rect->bottom - height_from_width;
      } else {
        rect->right = rect->left + width_from_height;
      }
      break;
    case WMSZ_BOTTOMLEFT:
      if (width > width_from_height) {
        rect->bottom = rect->top + height_from_width;
      } else {
        rect->left = rect->right - width_from_height;
      }
      break;
    case WMSZ_BOTTOMRIGHT:
      if (width > width_from_height) {
        rect->bottom = rect->top + height_from_width;
      } else {
        rect->right = rect->left + width_from_height;
      }
      break;
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  auto* messenger = flutter_controller_->engine()->messenger();
  display_power_method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "chessnut/windows_display_power",
          &flutter::StandardMethodCodec::GetInstance());
  display_power_method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "isDisplayOff") {
          result->Success(flutter::EncodableValue(display_off_));
          return;
        }
        result->NotImplemented();
      });
  display_power_event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          messenger, "chessnut/windows_display_power/events",
          &flutter::StandardMethodCodec::GetInstance());
  display_power_event_channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const auto*, auto&& sink) {
            display_power_event_sink_ = std::move(sink);
            display_power_event_sink_->Success(
                flutter::EncodableValue(display_off_));
            return nullptr;
          },
          [this](const auto*) {
            display_power_event_sink_.reset();
            return nullptr;
          }));
  display_power_notification_ = RegisterPowerSettingNotification(
      GetHandle(), &GUID_CONSOLE_DISPLAY_STATE, DEVICE_NOTIFY_WINDOW_HANDLE);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (display_power_notification_) {
    UnregisterPowerSettingNotification(display_power_notification_);
    display_power_notification_ = nullptr;
  }
  display_power_event_sink_.reset();
  if (display_power_event_channel_) {
    display_power_event_channel_->SetStreamHandler(nullptr);
  }
  display_power_event_channel_.reset();
  display_power_method_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_SIZING:
      KeepWindowAspectRatio(wparam, reinterpret_cast<RECT*>(lparam));
      return TRUE;
    case WM_POWERBROADCAST:
      if (wparam == PBT_POWERSETTINGCHANGE) {
        const auto* setting =
            reinterpret_cast<const POWERBROADCAST_SETTING*>(lparam);
        if (setting && setting->PowerSetting == GUID_CONSOLE_DISPLAY_STATE &&
            setting->DataLength >= sizeof(DWORD)) {
          const auto state = *reinterpret_cast<const DWORD*>(setting->Data);
          display_off_ = state == 0;
          if (display_power_event_sink_) {
            display_power_event_sink_->Success(
                flutter::EncodableValue(display_off_));
          }
          return TRUE;
        }
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
