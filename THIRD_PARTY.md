# Third-party components

- [godot-cpp](https://github.com/godotengine/godot-cpp/tree/godot-4.4-stable), Godot 4.4 stable, MIT. Its license must accompany redistributed plugin binaries; CMake stages it into `addons/webframe/bin/licenses`.
- [Microsoft.Web.WebView2 SDK](https://www.nuget.org/packages/Microsoft.Web.WebView2/1.0.2903.40), 1.0.2903.40. Headers and static loader are build-time dependencies; SDK license is staged alongside Windows binaries. The WebView2 Runtime is installed separately under Microsoft's terms.
- macOS Cocoa/WebKit and Linux GTK/WebKitGTK are dynamically linked system components; this repository does not redistribute them.
- Android System WebView and iOS UIKit/WebKit are system components and are not bundled.
- [AndroidX WebKit](https://developer.android.com/jetpack/androidx/releases/webkit), 1.12.1, Apache 2.0. Gradle resolves this dependency (and its transitive AndroidX libraries) into exported Android apps. Its license notices are retained by the Android build. The Godot Android library is a compile-only build dependency under Godot's MIT license.
