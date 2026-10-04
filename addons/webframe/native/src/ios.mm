#include "platform.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
static std::string text(NSString *s) { return s ? std::string(s.UTF8String) : std::string(); }
static NSString *ns(const std::string &s) { return [NSString stringWithUTF8String:s.c_str()]; }
@interface WebFrameIOSDelegate : NSObject <WKScriptMessageHandler, WKNavigationDelegate> {
@public std::shared_ptr<BrowserState> state;
}
@end
@implementation WebFrameIOSDelegate
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    if (!message.frameInfo.isMainFrame || ![message.body isKindOfClass:[NSString class]]) return;
    state->emit("message", text(message.body), text(message.frameInfo.request.URL.absoluteString));
}
- (void)webView:(WKWebView *)view didStartProvisionalNavigation:(WKNavigation *)navigation { state->emit("start", text(view.URL.absoluteString)); }
- (void)webView:(WKWebView *)view didFinishNavigation:(WKNavigation *)navigation { state->emit("finish", text(view.URL.absoluteString)); }
- (void)webView:(WKWebView *)view didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { state->emit("error", text(error.localizedDescription)); }
- (void)webView:(WKWebView *)view didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { state->emit("error", text(error.localizedDescription)); }
@end
class IOSBrowser : public Browser {
    std::shared_ptr<BrowserState> state;
    WKWebView *view = nil;
    WebFrameIOSDelegate *delegate = nil;
    UIView *parent = nil;
public:
    explicit IOSBrowser(std::shared_ptr<BrowserState> s) : state(s) {}
    ~IOSBrowser() override {
        [view stopLoading];
        [view.configuration.userContentController removeScriptMessageHandlerForName:@"webframe"];
        view.navigationDelegate = nil;
        [view removeFromSuperview]; view = nil; delegate = nil;
    }
    std::string open(int64_t window, int64_t, const std::string &server, const std::string &) override {
        if (server != "iOS" || !window || ![NSThread isMainThread]) return "WKWebView requires Godot's iOS view controller on the main thread.";
        UIViewController *controller = (__bridge UIViewController *)(reinterpret_cast<void *>(window));
        parent = controller.view;
        delegate = [WebFrameIOSDelegate new]; delegate->state = state;
        WKWebViewConfiguration *config = [WKWebViewConfiguration new];
        [config.userContentController addScriptMessageHandler:delegate name:@"webframe"];
        [config.userContentController addUserScript:[[WKUserScript alloc] initWithSource:ns(bridge_script) injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
        view = [[WKWebView alloc] initWithFrame:CGRectMake(0,0,1,1) configuration:config];
        view.navigationDelegate = delegate;
        view.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        view.hidden = YES;
        [parent addSubview:view]; state->emit("ready"); return {};
    }
    void bounds(int x,int y,int w,int h) override {
        CGFloat scale = parent.window.screen.scale ?: UIScreen.mainScreen.scale;
        view.frame = CGRectMake(x/scale, y/scale, w/scale, h/scale);
    }
    void visible(bool value) override { view.hidden = !value; }
    void transparent(bool value) override {
        view.opaque = !value;
        view.backgroundColor = value ? UIColor.clearColor : UIColor.whiteColor;
        view.scrollView.backgroundColor = view.backgroundColor;
    }
    void navigate(const std::string &url) override {
        NSURL *address = [NSURL URLWithString:ns(url)];
        if (address) [view loadRequest:[NSURLRequest requestWithURL:address]];
        else state->emit("error", "Invalid URL.");
    }
    void html(const std::string &s) override { [view loadHTMLString:ns(s) baseURL:[NSURL URLWithString:@"about:blank"]]; }
    void evaluate(const std::string &s) override { [view evaluateJavaScript:ns(s) completionHandler:nil]; }
};
std::unique_ptr<Browser> make_browser(std::shared_ptr<BrowserState> s) { return std::make_unique<IOSBrowser>(s); }
