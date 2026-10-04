#include "platform.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/rect2i.hpp>
using namespace godot;

const char *bridge_script = R"JS((()=>{
if(window.top!==window || window.WebFrame) return;
let serial=0; const pending=new Map();
const send = value => {
const text=JSON.stringify(value);
if(window.chrome?.webview) window.chrome.webview.postMessage(text);
else window.webkit.messageHandlers.webframe.postMessage(text);
};
window.WebFrame=Object.freeze({
call(method,...args){return new Promise((resolve,reject)=>{
const id=String(++serial); const timer=setTimeout(()=>{pending.delete(id);reject(new Error('WebFrame call timed out'));},15000);
pending.set(id,{resolve,reject,timer});
try{send({kind:'call',id,method,args});}catch(e){clearTimeout(timer);pending.delete(id);reject(e);}
});},
postMessage(data){send({kind:'message',data});},
_reply(id,value,error){const p=pending.get(id);if(!p)return;clearTimeout(p.timer);pending.delete(id);error?p.reject(new Error(error)):p.resolve(value);}
});
})();)JS";

class WebFrameBackend : public RefCounted {
    GDCLASS(WebFrameBackend, RefCounted)
    std::shared_ptr<BrowserState> state;
    std::unique_ptr<Browser> browser;
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("open", "window", "display", "server", "profile"), &WebFrameBackend::open);
        ClassDB::bind_method(D_METHOD("close"), &WebFrameBackend::close);
        ClassDB::bind_method(D_METHOD("set_bounds", "rect"), &WebFrameBackend::set_bounds);
        ClassDB::bind_method(D_METHOD("set_visible", "value"), &WebFrameBackend::set_visible);
        ClassDB::bind_method(D_METHOD("set_transparent", "value"), &WebFrameBackend::set_transparent);
        ClassDB::bind_method(D_METHOD("navigate", "url"), &WebFrameBackend::navigate);
        ClassDB::bind_method(D_METHOD("load_html", "html"), &WebFrameBackend::load_html);
        ClassDB::bind_method(D_METHOD("evaluate", "script"), &WebFrameBackend::evaluate);
        ClassDB::bind_method(D_METHOD("pump"), &WebFrameBackend::pump);
        ClassDB::bind_method(D_METHOD("poll"), &WebFrameBackend::poll);
    }
public:
    ~WebFrameBackend() { close(); }
    String open(int64_t window, int64_t display, String server, String profile) {
        close(); state = std::make_shared<BrowserState>(); browser = make_browser(state);
        auto error = browser->open(window, display, server.utf8().get_data(), profile.utf8().get_data());
        if (!error.empty()) close();
        return String::utf8(error.c_str());
    }
    void close() { if (state) state->alive = false; browser.reset(); state.reset(); }
    void set_bounds(Rect2i rect) { if (browser) browser->bounds(rect.position.x, rect.position.y, rect.size.x, rect.size.y); }
    void set_visible(bool value) { if (browser) browser->visible(value); }
    void set_transparent(bool value) { if (browser) browser->transparent(value); }
    void navigate(String value) { if (browser) browser->navigate(value.utf8().get_data()); }
    void load_html(String value) { if (browser) browser->html(value.utf8().get_data()); }
    void evaluate(String value) { if (browser) browser->evaluate(value.utf8().get_data()); }
    void pump() { if (browser) browser->pump(); }
    Array poll() {
        Array result;
        if (!state) return result;
        while (!state->events.empty()) {
            auto event = std::move(state->events.front()); state->events.pop_front();
            Dictionary item; item["type"] = String::utf8(event.type.c_str());
            item["data"] = String::utf8(event.data.c_str()); item["origin"] = String::utf8(event.origin.c_str()); result.push_back(item);
        }
        return result;
    }
};
static void initialize(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<WebFrameBackend>();
}
static void uninitialize(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT webframe_library_init(GDExtensionInterfaceGetProcAddress get_proc_address, GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize); init.register_terminator(uninitialize);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE); return init.init();
}
