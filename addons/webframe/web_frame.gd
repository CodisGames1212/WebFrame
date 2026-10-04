@tool
extends Control
## A native browser overlay. Browser pixels are not part of the Godot canvas.
## Call bind_js() to explicitly expose GDScript callables to trusted pages.

signal browser_ready
signal load_started(url: String)
signal load_finished(url: String)
signal error(message: String)
signal message_received(message: Variant)

@export var url: String = "about:blank":
	set(value):
		url = value
		if _backend != null and _ready_native:
			_backend.navigate(url)
@export var transparent_background: bool = false:
	set(value):
		transparent_background = value
		if _backend != null:
			_backend.set_transparent(value)
## Only exact origins listed here can call bound methods. Inline HTML uses "null".
## Empty means the bridge is disabled. Do not allow arbitrary untrusted sites.
@export var bridge_origins: PackedStringArray = PackedStringArray()

var _backend: Object
var _ready_native := false
var _bindings: Dictionary = {}
var _html := ""
var _use_html := false
var _last_rect := Rect2i()
var _last_visible := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if DisplayServer.get_name() == "headless":
		return
	if get_viewport() != get_window() or get_window().is_embedded():
		_fail("WebFrame requires a native Window viewport. SubViewports and embedded Windows are unsupported.")
		return
	if OS.get_name() == "Android":
		_backend = preload("res://addons/webframe/mobile/android_backend.gd").new()
	elif ClassDB.class_exists("WebFrameBackend"):
		_backend = ClassDB.instantiate("WebFrameBackend")
	else:
		_fail("WebFrame native library is missing. Build native/ or install a binary release.")
		return
	var window_id := get_window().get_window_id()
	var handle := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, window_id)
	var display := DisplayServer.window_get_native_handle(DisplayServer.DISPLAY_HANDLE, window_id)
	var problem: String = _backend.open(handle, display, DisplayServer.get_name(), ProjectSettings.globalize_path("user://webframe"))
	if not problem.is_empty():
		_fail(problem)
		_backend = null
		return
	_backend.set_transparent(transparent_background)
	_sync_bounds()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _backend == null:
		return
	_backend.pump()
	_sync_bounds()
	for event: Dictionary in _backend.poll():
		match event.get("type", ""):
			"ready":
				_ready_native = true
				if _use_html:
					_backend.load_html(_html)
				else:
					_backend.navigate(url)
				browser_ready.emit()
			"start": load_started.emit(event.get("data", ""))
			"finish": load_finished.emit(event.get("data", ""))
			"error": _fail(event.get("data", "Browser error"))
			"message": _dispatch(event.get("data", ""), event.get("origin", ""))

func _exit_tree() -> void:
	_ready_native = false
	if _backend != null:
		_backend.close()
		_backend = null

func _sync_bounds() -> void:
	var transform := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var bounds := Rect2i(transform * Rect2(Vector2.ZERO, size))
	var shown := is_visible_in_tree() and bounds.size.x > 0 and bounds.size.y > 0
	if bounds != _last_rect:
		_backend.set_bounds(bounds)
		_last_rect = bounds
	if shown != _last_visible:
		_backend.set_visible(shown)
		_last_visible = shown

func is_browser_ready() -> bool:
	return _ready_native

func load_html(html: String) -> void:
	_html = html
	_use_html = true
	if _backend != null and _ready_native:
		_backend.load_html(html)

func navigate(address: String) -> void:
	_use_html = false
	url = address

## Evaluate arbitrary JavaScript in the current page. Returns false if unavailable.
func call_js(script: String) -> bool:
	if _backend == null or not _ready_native:
		return false
	_backend.evaluate(script)
	return true

func reload() -> void:
	call_js("location.reload()")

func go_back() -> void:
	call_js("history.back()")

func go_forward() -> void:
	call_js("history.forward()")

## JavaScript: await WebFrame.call("name", arg1, arg2).
func bind_js(method_name: String, callback: Callable) -> void:
	assert(callback.is_valid(), "WebFrame requires a valid Callable")
	_bindings[method_name] = callback

func unbind_js(method_name: String) -> void:
	_bindings.erase(method_name)

func _dispatch(raw: String, source_url: String) -> void:
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return
	var origin := _origin(source_url)
	if not bridge_origins.has(origin):
		return
	if parsed.get("kind") == "message":
		message_received.emit(parsed.get("data"))
		return
	if parsed.get("kind") != "call":
		return
	var id: Variant = parsed.get("id")
	var method: String = str(parsed.get("method", ""))
	var args: Variant = parsed.get("args", [])
	if not id is String or not args is Array:
		return
	if not _bindings.has(method) or not (_bindings[method] as Callable).is_valid():
		_reply(id, null, "Unknown method: " + method)
		return
	var result: Variant = (_bindings[method] as Callable).callv(args)
	_reply(id, result, "")

func _reply(id: String, result: Variant, problem: String) -> void:
	call_js("window.WebFrame&&window.WebFrame._reply(%s,%s,%s)" % [JSON.stringify(id), JSON.stringify(result), JSON.stringify(problem)])

func _origin(address: String) -> String:
	if address == "null":
		return "null"
	if address.begins_with("about:") or address.begins_with("file:") or address.begins_with("data:") or address.is_empty():
		return "null"
	var scheme_end := address.find("://")
	if scheme_end < 0:
		return ""
	var authority_end := address.find("/", scheme_end + 3)
	return address.substr(0, authority_end if authority_end >= 0 else address.length()).to_lower()

func _fail(problem: String) -> void:
	error.emit(problem)
	push_error("WebFrame: " + problem)

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color("172735"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("76d6c5"), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(12, 24), "WebFrame · " + url, HORIZONTAL_ALIGNMENT_LEFT, maxf(0, size.x - 24), 14, Color("76d6c5"))
