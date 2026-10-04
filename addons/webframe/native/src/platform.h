#pragma once
#include <cstdint>
#include <deque>
#include <memory>
#include <string>

struct BrowserEvent { std::string type, data, origin; };
struct BrowserState {
    bool alive = true;
    std::deque<BrowserEvent> events;
    void emit(std::string type, std::string data = {}, std::string origin = {}) {
        if (alive && events.size() < 1024) events.push_back({type, data, origin});
    }
};
class Browser {
public:
    virtual ~Browser() = default;
    virtual std::string open(int64_t window, int64_t display, const std::string &server, const std::string &profile) = 0;
    virtual void bounds(int x, int y, int width, int height) = 0;
    virtual void visible(bool value) = 0;
    virtual void transparent(bool value) = 0;
    virtual void navigate(const std::string &url) = 0;
    virtual void html(const std::string &content) = 0;
    virtual void evaluate(const std::string &script) = 0;
    virtual void pump() {}
};
std::unique_ptr<Browser> make_browser(std::shared_ptr<BrowserState> state);
extern const char *bridge_script;
