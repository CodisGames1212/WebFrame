#include "platform.h"
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <wrl/client.h>
#include <wrl/event.h>
#include <WebView2.h>
#include <algorithm>
#include <filesystem>
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::Callback;
static std::wstring wide(const std::string &s) {
    int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, nullptr, 0);
    std::wstring r(n, 0); MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, r.data(), n); return r;
}
static std::string utf8(const wchar_t *s) {
    if (!s) return {};
    int n = WideCharToMultiByte(CP_UTF8, 0, s, -1, nullptr, 0, nullptr, nullptr);
    std::string r(n, 0); WideCharToMultiByte(CP_UTF8, 0, s, -1, r.data(), n, nullptr, nullptr); r.pop_back(); return r;
}
struct WindowsData {
    std::shared_ptr<BrowserState> state;
    ComPtr<ICoreWebView2Controller> controller;
    ComPtr<ICoreWebView2> view;
    RECT rect{0, 0, 1, 1}; bool shown = false, clear = false;
    bool com_initialized = false;
    void apply() {
        if (!controller) return;
        controller->put_Bounds(rect); controller->put_IsVisible(shown);
        ComPtr<ICoreWebView2Controller2> c2;
        if (SUCCEEDED(controller.As(&c2))) c2->put_DefaultBackgroundColor({static_cast<BYTE>(clear ? 0 : 255), 255, 255, 255});
    }
};
class WindowsBrowser : public Browser {
    std::shared_ptr<WindowsData> d = std::make_shared<WindowsData>();
public:
    explicit WindowsBrowser(std::shared_ptr<BrowserState> s) { d->state = s; }
    ~WindowsBrowser() override {
        d->state->alive = false;
        if (d->controller) d->controller->Close();
        d->view.Reset(); d->controller.Reset();
        if (d->com_initialized) CoUninitialize();
    }
    std::string open(int64_t window, int64_t, const std::string &server, const std::string &profile) override {
        if (server != "Windows" || !window) return "A native Windows game window is required.";
        HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        if (FAILED(hr)) return "WebView2 requires the main thread's COM apartment to be STA.";
        d->com_initialized = true;
        std::error_code ec; std::filesystem::create_directories(std::filesystem::u8path(profile), ec);
        if (ec) return "Cannot create WebView2 user-data directory: " + ec.message();
        std::weak_ptr<WindowsData> weak = d;
        hr = CreateCoreWebView2EnvironmentWithOptions(nullptr, wide(profile).c_str(), nullptr,
            Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>([weak, window](HRESULT result, ICoreWebView2Environment *env) -> HRESULT {
                auto p = weak.lock(); if (!p || !p->state->alive) return S_OK;
                if (FAILED(result) || !env) { p->state->emit("error", "WebView2 initialization failed. Install the Microsoft Edge WebView2 Runtime."); return S_OK; }
                HRESULT creation = env->CreateCoreWebView2Controller(reinterpret_cast<HWND>(window),
                    Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>([weak](HRESULT status, ICoreWebView2Controller *controller) -> HRESULT {
                        auto p = weak.lock(); if (!p || !p->state->alive) { if (controller) controller->Close(); return S_OK; }
                        if (FAILED(status) || !controller) { p->state->emit("error", "Could not attach WebView2 to the Godot window."); return S_OK; }
                        p->controller = controller; controller->get_CoreWebView2(&p->view); p->apply();
                        EventRegistrationToken token{};
                        p->view->add_WebMessageReceived(Callback<ICoreWebView2WebMessageReceivedEventHandler>([weak](ICoreWebView2 *, ICoreWebView2WebMessageReceivedEventArgs *args) -> HRESULT {
                            auto p = weak.lock(); if (!p || !p->state->alive) return S_OK;
                            LPWSTR text = nullptr, source = nullptr;
                            if (SUCCEEDED(args->TryGetWebMessageAsString(&text))) { args->get_Source(&source); p->state->emit("message", utf8(text), utf8(source)); }
                            CoTaskMemFree(text); CoTaskMemFree(source); return S_OK;
                        }).Get(), &token);
                        p->view->add_NavigationStarting(Callback<ICoreWebView2NavigationStartingEventHandler>([weak](ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *args) -> HRESULT {
                            auto p = weak.lock(); if (!p || !p->state->alive) return S_OK;
                            LPWSTR uri = nullptr; args->get_Uri(&uri); p->state->emit("start", utf8(uri)); CoTaskMemFree(uri); return S_OK;
                        }).Get(), &token);
                        p->view->add_NavigationCompleted(Callback<ICoreWebView2NavigationCompletedEventHandler>([weak](ICoreWebView2 *sender, ICoreWebView2NavigationCompletedEventArgs *args) -> HRESULT {
                            auto p = weak.lock(); if (!p || !p->state->alive) return S_OK;
                            BOOL success = false; args->get_IsSuccess(&success);
                            LPWSTR uri = nullptr; sender->get_Source(&uri);
                            p->state->emit(success ? "finish" : "error", success ? utf8(uri) : "WebView2 navigation failed."); CoTaskMemFree(uri); return S_OK;
                        }).Get(), &token);
                        p->view->add_NewWindowRequested(Callback<ICoreWebView2NewWindowRequestedEventHandler>([](ICoreWebView2 *, ICoreWebView2NewWindowRequestedEventArgs *args) -> HRESULT {
                            args->put_Handled(TRUE); return S_OK;
                        }).Get(), &token);
                        p->view->AddScriptToExecuteOnDocumentCreated(wide(bridge_script).c_str(),
                            Callback<ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler>([weak](HRESULT status, LPCWSTR) -> HRESULT {
                                auto p = weak.lock(); if (p) p->state->emit(FAILED(status) ? "error" : "ready", FAILED(status) ? "Could not install JavaScript bridge." : ""); return S_OK;
                            }).Get());
                        return S_OK;
                    }).Get());
                if (FAILED(creation)) p->state->emit("error", "WebView2 controller creation failed.");
                return S_OK;
            }).Get());
        return FAILED(hr) ? "WebView2 could not start. Install the Microsoft Edge WebView2 Runtime." : "";
    }
    void bounds(int x, int y, int w, int h) override { d->rect = {x, y, x + std::max(w, 1), y + std::max(h, 1)}; d->apply(); }
    void visible(bool v) override { d->shown = v; d->apply(); }
    void transparent(bool v) override { d->clear = v; d->apply(); }
    void navigate(const std::string &url) override { if (d->view) d->view->Navigate(wide(url).c_str()); }
    void html(const std::string &s) override { if (d->view) d->view->NavigateToString(wide(s).c_str()); }
    void evaluate(const std::string &s) override { if (d->view) d->view->ExecuteScript(wide(s).c_str(), nullptr); }
};
std::unique_ptr<Browser> make_browser(std::shared_ptr<BrowserState> s) { return std::make_unique<WindowsBrowser>(s); }
