// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

#include "store_donations.h"

#include <appmodel.h>
#include <flutter/standard_method_codec.h>
#include <shobjidl.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Services.Store.h>

#include <string>
#include <vector>

namespace store_donations {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Foundation::AsyncStatus;
using winrt::Windows::Foundation::IAsyncOperation;
using winrt::Windows::Services::Store::StoreConsumableResult;
using winrt::Windows::Services::Store::StoreContext;
using winrt::Windows::Services::Store::StoreProductQueryResult;
using winrt::Windows::Services::Store::StorePurchaseResult;
using winrt::Windows::Services::Store::StorePurchaseStatus;

using Result = std::shared_ptr<flutter::MethodResult<EncodableValue>>;

// Consumibles que maneja la app ("developer-managed"): se confirman con
// ReportConsumableFulfillmentAsync y se pueden volver a comprar.
constexpr wchar_t kConsumableKind[] = L"UnmanagedConsumable";

// La Store solo responde a apps instaladas desde ella (con identidad de
// paquete MSIX). Fuera de eso no hay nada que ofrecer.
bool HasPackageIdentity() {
  UINT32 length = 0;
  return GetCurrentPackageFullName(&length, nullptr) !=
         APPMODEL_ERROR_NO_PACKAGE;
}

winrt::Windows::Foundation::Collections::IIterable<winrt::hstring>
ConsumableKinds() {
  return winrt::single_threaded_vector<winrt::hstring>({kConsumableKind});
}

// En una app de escritorio, el diálogo de compra necesita saber sobre qué
// ventana abrirse.
StoreContext ContextFor(HWND window) {
  StoreContext context = StoreContext::GetDefault();
  context.as<::IInitializeWithWindow>()->Initialize(window);
  return context;
}

std::string StatusName(StorePurchaseStatus status) {
  switch (status) {
    case StorePurchaseStatus::Succeeded:
      return "succeeded";
    case StorePurchaseStatus::AlreadyPurchased:
      return "alreadyPurchased";
    case StorePurchaseStatus::NotPurchased:
      return "notPurchased";
    case StorePurchaseStatus::NetworkError:
      return "networkError";
    default:
      return "serverError";
  }
}

// Confirma la compra para que el complemento se pueda volver a comprar, y
// después llama a |done|.
void Fulfill(StoreContext context, const winrt::hstring& store_id,
             std::function<void()> done) {
  GUID tracking;
  if (FAILED(CoCreateGuid(&tracking))) {
    done();
    return;
  }
  // Un consumible manejado por la app se confirma con cantidad 1.
  context.ReportConsumableFulfillmentAsync(store_id, 1, winrt::guid(tracking))
      .Completed([done](IAsyncOperation<StoreConsumableResult> const&,
                        AsyncStatus) { done(); });
}

void Offers(HWND window, Result result, RunOnUi run_on_ui) {
  if (!HasPackageIdentity()) {
    result->Success(EncodableValue(EncodableList{}));
    return;
  }
  ContextFor(window)
      .GetAssociatedStoreProductsAsync(ConsumableKinds())
      .Completed([result, run_on_ui](
                     IAsyncOperation<StoreProductQueryResult> const& operation,
                     AsyncStatus status) {
        EncodableList offers;
        if (status == AsyncStatus::Completed) {
          for (auto const& entry : operation.GetResults().Products()) {
            auto const& product = entry.Value();
            offers.push_back(EncodableValue(EncodableMap{
                {EncodableValue("storeId"),
                 EncodableValue(winrt::to_string(product.StoreId()))},
                {EncodableValue("token"),
                 EncodableValue(winrt::to_string(product.InAppOfferToken()))},
                {EncodableValue("price"),
                 EncodableValue(
                     winrt::to_string(product.Price().FormattedPrice()))},
            }));
          }
        }
        run_on_ui([result, offers]() {
          result->Success(EncodableValue(offers));
        });
      });
}

void Purchase(HWND window, const std::string& store_id, Result result,
              RunOnUi run_on_ui) {
  if (!HasPackageIdentity()) {
    result->Success(EncodableValue("serverError"));
    return;
  }
  StoreContext context = ContextFor(window);
  winrt::hstring id = winrt::to_hstring(store_id);
  context.RequestPurchaseAsync(id).Completed(
      [context, id, result, run_on_ui](
          IAsyncOperation<StorePurchaseResult> const& operation,
          AsyncStatus status) {
        StorePurchaseStatus purchase = StorePurchaseStatus::ServerError;
        if (status == AsyncStatus::Completed) {
          purchase = operation.GetResults().Status();
        }
        auto reply = [result, run_on_ui, name = StatusName(purchase)]() {
          run_on_ui([result, name]() { result->Success(EncodableValue(name)); });
        };
        // "Ya comprado" es una compra anterior sin confirmar: se confirma
        // ahora, igual que una nueva.
        if (purchase == StorePurchaseStatus::Succeeded ||
            purchase == StorePurchaseStatus::AlreadyPurchased) {
          Fulfill(context, id, reply);
        } else {
          reply();
        }
      });
}

// Al arrancar: confirma las compras que quedaron sin confirmar (la app se
// cerró durante el pago). Responde cuántas había.
void FulfillPending(HWND window, Result result, RunOnUi run_on_ui) {
  if (!HasPackageIdentity()) {
    result->Success(EncodableValue(0));
    return;
  }
  StoreContext context = ContextFor(window);
  context.GetUserCollectionAsync(ConsumableKinds())
      .Completed([context, result, run_on_ui](
                     IAsyncOperation<StoreProductQueryResult> const& operation,
                     AsyncStatus status) {
        int32_t pending = 0;
        if (status == AsyncStatus::Completed) {
          for (auto const& entry : operation.GetResults().Products()) {
            Fulfill(context, entry.Value().StoreId(), []() {});
            ++pending;
          }
        }
        run_on_ui(
            [result, pending]() { result->Success(EncodableValue(pending)); });
      });
}

}  // namespace

StoreDonationsChannel::StoreDonationsChannel(flutter::BinaryMessenger* messenger,
                                             HWND window, RunOnUi run_on_ui)
    : window_(window), run_on_ui_(std::move(run_on_ui)) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "com.lockspire.lockspire/store_donations",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> reply) {
        Result result(std::move(reply));
        try {
          const auto* args = call.arguments();
          if (call.method_name() == "offers") {
            Offers(window_, result, run_on_ui_);
          } else if (call.method_name() == "purchase" && args &&
                     std::holds_alternative<std::string>(*args)) {
            Purchase(window_, std::get<std::string>(*args), result,
                     run_on_ui_);
          } else if (call.method_name() == "fulfillPending") {
            FulfillPending(window_, result, run_on_ui_);
          } else {
            result->NotImplemented();
          }
        } catch (winrt::hresult_error const& error) {
          result->Error("STORE_ERROR", winrt::to_string(error.message()));
        }
      });
}

StoreDonationsChannel::~StoreDonationsChannel() {
  channel_->SetMethodCallHandler(nullptr);
}

}  // namespace store_donations
