#include "platform.h"
#include <gtk/gtk.h>
#include <gtk/gtkx.h>
#include <gdk/gdkx.h>
#include <webkit2/webkit2.h>
#include <X11/Xlib.h>
#include <algorithm>
class LinuxBrowser : public Browser {
    std::shared_ptr<BrowserState> state;
    GtkWidget *plug = nullptr;
    WebKitWebView *view = nullptr;
    WebKitUserContentManager *manager = nullptr;
    Display *display = nullptr;
    ::Window child = 0;
public:
    explicit LinuxBrowser(std::shared_ptr<BrowserState> s) : state(s) {}
    ~LinuxBrowser() override {
        if (manager) g_signal_handlers_disconnect_by_data(manager, this);
        if (view) { g_signal_handlers_disconnect_by_data(view, this); webkit_web_view_stop_loading(view); }
        if (plug) gtk_widget_destroy(plug);
        if (manager) g_object_unref(manager);
    }
    std::string open(int64_t window, int64_t, const std::string &server, const std::string &) override {
        if (server != "X11" || !window) return "Linux native embedding currently requires Godot's X11 display server. Start Godot with --display-driver x11.";
        gdk_set_allowed_backends("x11");
        if (!gtk_init_check(nullptr, nullptr)) return "GTK could not connect to the X11 display.";
        if (!GDK_IS_X11_DISPLAY(gdk_display_get_default())) return "GTK must use its X11 backend.";
        manager = webkit_user_content_manager_new();
        g_signal_connect(manager, "script-message-received::webframe", G_CALLBACK(+[](WebKitUserContentManager *, WebKitJavascriptResult *result, gpointer data) {
            auto self = static_cast<LinuxBrowser *>(data);
            JSCValue *value = webkit_javascript_result_get_js_value(result);
            if (!jsc_value_is_string(value)) return;
            char *message = jsc_value_to_string(value);
            const char *uri = webkit_web_view_get_uri(self->view);
            self->state->emit("message", message ? message : "", uri ? uri : ""); g_free(message);
        }), this);
        webkit_user_content_manager_register_script_message_handler(manager, "webframe");
        WebKitUserScript *script = webkit_user_script_new(bridge_script, WEBKIT_USER_CONTENT_INJECT_TOP_FRAME, WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START, nullptr, nullptr);
        webkit_user_content_manager_add_script(manager, script); webkit_user_script_unref(script);
        view = WEBKIT_WEB_VIEW(webkit_web_view_new_with_user_content_manager(manager));
        g_signal_connect(view, "load-changed", G_CALLBACK(+[](WebKitWebView *view, WebKitLoadEvent event, gpointer data) {
            auto self = static_cast<LinuxBrowser *>(data); const char *uri = webkit_web_view_get_uri(view);
            if (event == WEBKIT_LOAD_STARTED) self->state->emit("start", uri ? uri : "");
            if (event == WEBKIT_LOAD_FINISHED) self->state->emit("finish", uri ? uri : "");
        }), this);
        g_signal_connect(view, "load-failed", G_CALLBACK(+[](WebKitWebView *, WebKitLoadEvent, const char *, GError *error, gpointer data) -> gboolean {
            static_cast<LinuxBrowser *>(data)->state->emit("error", error->message); return FALSE;
        }), this);
        plug = gtk_plug_new(0);
        GdkVisual *visual = gdk_screen_get_rgba_visual(gtk_widget_get_screen(plug));
        if (visual) gtk_widget_set_visual(plug, visual);
        gtk_widget_set_app_paintable(plug, TRUE);
        gtk_container_add(GTK_CONTAINER(plug), GTK_WIDGET(view));
        gtk_widget_realize(plug);
        display = GDK_DISPLAY_XDISPLAY(gdk_display_get_default());
        child = gtk_plug_get_id(GTK_PLUG(plug));
        XReparentWindow(display, child, static_cast<::Window>(window), 0, 0);
        XFlush(display); state->emit("ready"); return {};
    }
    void bounds(int x,int y,int w,int h) override {
        gtk_widget_set_size_request(GTK_WIDGET(view), std::max(w,1), std::max(h,1));
        gtk_window_resize(GTK_WINDOW(plug), std::max(w,1), std::max(h,1));
        XMoveResizeWindow(display, child, x, y, std::max(w,1), std::max(h,1)); XFlush(display);
    }
    void visible(bool v) override { if (v) gtk_widget_show_all(plug); else gtk_widget_hide(plug); }
    void transparent(bool v) override { GdkRGBA color{1,1,1,v ? 0.0 : 1.0}; webkit_web_view_set_background_color(view, &color); }
    void navigate(const std::string &s) override { webkit_web_view_load_uri(view, s.c_str()); }
    void html(const std::string &s) override { webkit_web_view_load_html(view, s.c_str(), "about:blank"); }
    void evaluate(const std::string &s) override { webkit_web_view_evaluate_javascript(view, s.c_str(), -1, nullptr, nullptr, nullptr, nullptr, nullptr); }
    void pump() override { for (int n=0; n<32 && g_main_context_pending(nullptr); ++n) g_main_context_iteration(nullptr, FALSE); }
};
std::unique_ptr<Browser> make_browser(std::shared_ptr<BrowserState> s) { return std::make_unique<LinuxBrowser>(s); }
