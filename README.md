# WebFrame

WebFrame is a native embedded browser plugin for Godot 4.4+ that displays webpages using the operating system's web engine.

## Install

Download `WebFrame-all-platforms` from [GitHub Actions](https://github.com/CodisGames1212/WebFrame/actions) after a successful build, unzip the artifact and its contained ZIP, and copy `addons/webframe` into your project. Tagged releases attach the ZIP to [Releases](https://github.com/CodisGames1212/WebFrame/releases).

Enable **WebFrame** in Project Settings > Plugins and add a `WebFrame` Control node. Run the game in a separate native window with embedded play disabled. The editor displays a placeholder.

```gdscript
func _ready():
    $WebFrame.bridge_origins = PackedStringArray(["https://example.com"])
    $WebFrame.bind_js("greet", func(name): return "Hello, " + str(name))
    $WebFrame.navigate("https://example.com")
```

```javascript
const reply = await WebFrame.call("greet", "player");
WebFrame.postMessage({score: 42});
```

Only bound methods are exposed. Set exact trusted origins in `bridge_origins`; use `"null"` only for trusted inline HTML. An empty list disables the bridge.

Other methods: `load_html`, `call_js`, `reload`, `go_back`, `go_forward`, `unbind_js`, and `is_browser_ready`. Signals: `browser_ready`, `load_started`, `load_finished`, `message_received`, and `error`.

## Platforms

| Build | Browser / requirements |
| --- | --- |
| Windows x64, x86, ARM64 | WebView2; install the WebView2 Runtime |
| macOS universal (Intel + Apple Silicon) | System WKWebView |
| Linux x64, ARM64 | X11 and WebKitGTK 4.1; Wayland requires XWayland |
| Android (one AAR for all engine architectures) | System WebView; enable the addon and use Godot's Gradle export |
| iOS ARM64 device | System WKWebView; sign the library with the exported app in Xcode |

iOS device integration still requires validation on hardware. Simulator and Web exports are unsupported. WebFrame uses native overlays rather than viewport textures: 3D transforms, SubViewports, screenshots, clipping, and drawing Godot UI over the browser are unsupported.

## Build

The minimal CI workflow adapts the platform matrix and merged addon packaging from [godot-plus-plus](https://github.com/nikoladevelops/godot-plus-plus), retaining WebFrame's CMake/Gradle backends. Every push to `main`, pull request, or manual run builds all listed targets. Push a `v*` tag to create a release after all builds succeed.

Native builds need CMake 3.24+, Python 3, Git, and a C++17 compiler. Dependencies are fetched at build time; binaries and generated projects are excluded from source control.

```sh
# Windows: -A x64, Win32, or ARM64
cmake -S addons/webframe/native -B build -A x64
cmake --build build --config Release --parallel 4

# macOS / iOS
bash tools/build_macos.sh
bash tools/build_ios.sh

# Linux: install libwebkit2gtk-4.1-dev and libx11-dev first
bash tools/build_linux.sh

# Android: Java 17, Gradle 8.11.1, Android SDK 35
 gradle -p addons/webframe/mobile/android :webframe:stagePlugin --no-daemon
```

Open `project.godot` for a small browser/JavaScript bridge demo. Runtime checks are in `tests/` (run `godot --headless --path . --script tests/bridge_test.gd` after importing the project). `python tools/package.py` creates the addon ZIP and fails if any CI binary is missing.

MIT license. See [LICENSE](LICENSE) and [THIRD_PARTY.md](THIRD_PARTY.md).
