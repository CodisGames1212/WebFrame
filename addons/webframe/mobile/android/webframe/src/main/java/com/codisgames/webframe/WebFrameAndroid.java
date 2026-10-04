package com.codisgames.webframe;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import java.io.OutputStream;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.view.View;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.util.Collections;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Consumer;

/** UI-thread WebViews with a per-node concurrent queue polled by Godot. */
public final class WebFrameAndroid extends GodotPlugin {
    private FrameLayout layer;
    private final AtomicInteger nextId = new AtomicInteger(1);
    private final ConcurrentHashMap<Integer, Session> sessions = new ConcurrentHashMap<>();
    private static final class Session {
        volatile boolean alive = true;
        WebView view;
        final ConcurrentLinkedQueue<JSONObject> events = new ConcurrentLinkedQueue<>();
        final AtomicInteger count = new AtomicInteger();
        void emit(String type, String data, String origin) {
            if (!alive) return;
            if (count.incrementAndGet() > 1024) { count.decrementAndGet(); return; }
            try { events.add(new JSONObject().put("type", type).put("data", data).put("origin", origin)); }
            catch (JSONException ignored) { count.decrementAndGet(); }
        }
    }
    private static final String BRIDGE = "(()=>{if(window.top!==window||window.WebFrame)return;"
        + "let serial=0;const pending=new Map();const send=v=>webframeNative.postMessage(JSON.stringify(v));"
        + "window.WebFrame=Object.freeze({call(method,...args){return new Promise((resolve,reject)=>{"
        + "const id=String(++serial);const timer=setTimeout(()=>{pending.delete(id);reject(new Error('WebFrame call timed out'));},15000);"
        + "pending.set(id,{resolve,reject,timer});try{send({kind:'call',id,method,args});}catch(e){clearTimeout(timer);pending.delete(id);reject(e);}});},"
        + "postMessage(data){send({kind:'message',data});},_reply(id,value,error){const p=pending.get(id);if(!p)return;"
        + "clearTimeout(p.timer);pending.delete(id);error?p.reject(new Error(error)):p.resolve(value);}});})();";
    public WebFrameAndroid(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "WebFrameAndroid"; }
    /** Called by the trusted local demo bridge; no broad storage permission required. */
    @UsedByGodot public String save_download(String filename, String mime, String encoded) {
        Activity activity = getActivity();
        if (activity == null) return "Android activity is unavailable.";
        if (Build.VERSION.SDK_INT < 29) return "Export to Downloads requires Android 10 or later.";
        if (encoded.length() > 32 * 1024 * 1024) return "Export is too large (maximum 24 MB).";
        String safeName = filename.replaceAll("[\\\\/<>:\"|?*\\p{Cntrl}]", "-").trim();
        if (safeName.isEmpty() || safeName.equals(".") || safeName.equals("..")) return "Invalid export filename.";
        ContentResolver resolver = activity.getContentResolver();
        Uri uri = null;
        try {
            byte[] bytes = Base64.decode(encoded, Base64.DEFAULT);
            ContentValues values = new ContentValues();
            values.put(MediaStore.MediaColumns.DISPLAY_NAME, safeName);
            values.put(MediaStore.MediaColumns.MIME_TYPE, mime);
            values.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/WebFrame");
            values.put(MediaStore.MediaColumns.IS_PENDING, 1);
            uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
            if (uri == null) return "Unable to create export in Downloads.";
            try (OutputStream stream = resolver.openOutputStream(uri)) {
                if (stream == null) throw new java.io.IOException("Unable to open export file");
                stream.write(bytes);
            }
            values.clear();
            values.put(MediaStore.MediaColumns.IS_PENDING, 0);
            if (resolver.update(uri, values, null, null) != 1)
                throw new java.io.IOException("Unable to finish export");
            return "";
        } catch (Exception error) {
            if (uri != null) {
                try { resolver.delete(uri, null, null); } catch (RuntimeException ignored) { }
            }
            return "Export failed: " + error.getMessage();
        }
    }
    @Override public View onMainCreate(Activity activity) {
        layer = new FrameLayout(activity);
        layer.setClipChildren(true);
        layer.setLayoutParams(new FrameLayout.LayoutParams(-1, -1));
        return layer;
    }
    private void ui(Runnable action) {
        Activity activity = getActivity();
        if (activity != null) activity.runOnUiThread(action);
    }
    private void withView(int id, Consumer<WebView> action) {
        Session s = sessions.get(id);
        if (s == null) return;
        ui(() -> {
            if (!s.alive || s.view == null) return;
            try { action.accept(s.view); }
            catch (RuntimeException e) { s.emit("error", e.toString(), ""); }
        });
    }
    @UsedByGodot public int create_view() {
        if (getActivity() == null) return 0;
        int id = nextId.getAndIncrement();
        Session s = new Session(); sessions.put(id, s);
        ui(() -> {
            if (!s.alive) return;
            try {
                if (layer == null) throw new IllegalStateException("Godot overlay layer is not ready");
                if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)
                    || !WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT))
                    throw new IllegalStateException("Update Android System WebView: secure messaging and document-start scripts are required");
                WebView view = new WebView(getActivity()); s.view = view;
                view.setVisibility(View.INVISIBLE);
                view.getSettings().setJavaScriptEnabled(true);
                view.getSettings().setDomStorageEnabled(true);
                view.getSettings().setAllowFileAccess(false);
                view.getSettings().setAllowContentAccess(false);
                view.getSettings().setSupportMultipleWindows(false);
                view.setWebViewClient(new WebViewClient() {
                    @Override public void onPageStarted(WebView v, String url, Bitmap icon) { s.emit("start", url, ""); }
                    @Override public void onPageFinished(WebView v, String url) { s.emit("finish", url, ""); }
                    @Override public void onReceivedError(WebView v, WebResourceRequest request, WebResourceError error) {
                        if (request.isForMainFrame()) s.emit("error", error.getDescription().toString(), "");
                    }
                    @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest request) {
                        String scheme = request.getUrl().getScheme();
                        return !("https".equals(scheme) || "http".equals(scheme) || "about".equals(scheme));
                    }
                });
                WebViewCompat.addWebMessageListener(view, "webframeNative", Collections.singleton("*"),
                    (v, message, origin, mainFrame, reply) -> {
                        if (mainFrame && message.getData() != null) s.emit("message", message.getData(), origin.toString());
                    });
                WebViewCompat.addDocumentStartJavaScript(view, BRIDGE, Collections.singleton("*"));
                layer.addView(view, new FrameLayout.LayoutParams(1, 1));
                s.emit("ready", "", "");
            } catch (RuntimeException e) { s.emit("error", e.toString(), ""); }
        });
        return id;
    }
    @UsedByGodot public void destroy_view(int id) {
        Session s = sessions.remove(id); if (s == null) return;
        s.alive = false; s.events.clear();
        ui(() -> {
            if (s.view == null) return;
            s.view.stopLoading();
            if (s.view.getParent() instanceof android.view.ViewGroup)
                ((android.view.ViewGroup) s.view.getParent()).removeView(s.view);
            s.view.destroy(); s.view = null;
        });
    }
    @UsedByGodot public String poll_view(int id) {
        Session s = sessions.get(id); JSONArray events = new JSONArray();
        if (s != null) {
            JSONObject event;
            while ((event = s.events.poll()) != null) { s.count.decrementAndGet(); events.put(event); }
        }
        return events.toString();
    }
    @UsedByGodot public void set_view_bounds(int id, int x, int y, int width, int height) {
        withView(id, v -> {
            FrameLayout.LayoutParams p = new FrameLayout.LayoutParams(Math.max(1,width), Math.max(1,height));
            p.leftMargin=x; p.topMargin=y; v.setLayoutParams(p);
        });
    }
    @UsedByGodot public void set_view_visible(int id, boolean visible) { withView(id, v -> v.setVisibility(visible ? View.VISIBLE : View.INVISIBLE)); }
    @UsedByGodot public void set_view_transparent(int id, boolean clear) { withView(id, v -> v.setBackgroundColor(clear ? Color.TRANSPARENT : Color.WHITE)); }
    @UsedByGodot public void navigate_view(int id, String url) { withView(id, v -> v.loadUrl(url)); }
    @UsedByGodot public void load_view_html(int id, String html) { withView(id, v -> v.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)); }
    @UsedByGodot public void evaluate_view(int id, String script) { withView(id, v -> v.evaluateJavascript(script, null)); }
    @Override public void onMainPause() { for (Session s : sessions.values()) if (s.view != null) s.view.onPause(); }
    @Override public void onMainResume() { for (Session s : sessions.values()) if (s.view != null) s.view.onResume(); }
    @Override public void onMainDestroy() {
        for (Integer id : sessions.keySet()) destroy_view(id);
        layer = null;
    }
}
