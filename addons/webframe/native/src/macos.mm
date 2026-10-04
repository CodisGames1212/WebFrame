#include "platform.h"
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
static std::string text(NSString *s) { return s ? std::string(s.UTF8String) : std::string(); }
static NSString *ns(const std::string &s) { return [NSString stringWithUTF8String:s.c_str()]; }
@interface WebFrameDelegate : NSObject <WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate> {
@public std::shared_ptr<BrowserState> state;
}
@end
@implementation WebFrameDelegate
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    if (!message.frameInfo.isMainFrame || ![message.body isKindOfClass:[NSString class]]) return;
    state->emit("message", text(message.body), text(message.frameInfo.request.URL.absoluteString));
}
- (void)webView:(WKWebView *)view didStartProvisionalNavigation:(WKNavigation *)navigation { state->emit("start", text(view.URL.absoluteString)); }
- (void)webView:(WKWebView *)view didFinishNavigation:(WKNavigation *)navigation { state->emit("finish", text(view.URL.absoluteString)); }
- (void)webView:(WKWebView *)view didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { state->emit("error", text(error.localizedDescription)); }
- (void)webView:(WKWebView *)view didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { state->emit("error", text(error.localizedDescription)); }
@end
class MacBrowser : public Browser {
    std::shared_ptr<BrowserState> state;
    WKWebView *view = nil;
    WebFrameDelegate *delegate = nil;
    NSView *parent = nil;
public:
    explicit MacBrowser(std::shared_ptr<BrowserState> s) : state(s) {}
    ~MacBrowser() override {
        [view stopLoading];
        [view.configuration.userContentController removeScriptMessageHandlerForName:@"webframe"];
        view.navigationDelegate = nil; view.UIDelegate = nil;
        [view removeFromSuperview]; view = nil; delegate = nil;
    }
    std::string open(int64_t window, int64_t, const std::string &server, const std::string &) override {
        if (server != "macOS" || !window || ![NSThread isMainThread]) return "WKWebView requires a macOS window on the main thread.";
        NSWindow *native = (__bridge NSWindow *)(reinterpret_cast<void *>(window));
        parent = native.contentView;
        delegate = [WebFrameDelegate new]; delegate->state = state;
        WKWebViewConfiguration *config = [WKWebViewConfiguration new];
        [config.userContentController addScriptMessageHandler:delegate name:@"webframe"];
        [config.userContentController addUserScript:[[WKUserScript alloc] initWithSource:ns(bridge_script) injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
        view = [[WKWebView alloc] initWithFrame:NSMakeRect(0,0,1,1) configuration:config];
        view.navigationDelegate = delegate; view.UIDelegate = delegate; view.hidden = YES;
        [parent addSubview:view]; state->emit("ready"); return {};
    }
    void bounds(int x,int y,int w,int h) override {
        CGFloat scale = parent.window.backingScaleFactor;
        CGFloat height = parent.bounds.size.height;
        view.frame = NSMakeRect(x/scale, parent.isFlipped ? y/scale : height-(y+h)/scale, w/scale, h/scale);
    }
    void visible(bool value) override { view.hidden = !value; }
    void transparent(bool value) override { [view setValue:@(!value) forKey:@"drawsBackground"]; }
    void navigate(const std::string &url) override {
        NSURL *address = [NSURL URLWithString:ns(url)];
        if (address) [view loadRequest:[NSURLRequest requestWithURL:address]];
        else state->emit("error", "Invalid URL.");
    }
    void html(const std::string &s) override { [view loadHTMLString:ns(s) baseURL:[NSURL URLWithString:@"about:blank"]]; }
    void evaluate(const std::string &s) override { [view evaluateJavaScript:ns(s) completionHandler:nil]; }
};
std::unique_ptr<Browser> make_browser(std::shared_ptr<BrowserState> s) { return std::make_unique<MacBrowser>(s); }
