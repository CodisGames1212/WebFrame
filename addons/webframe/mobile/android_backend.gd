extends RefCounted
## Adapts the Android v2 plugin to the desktop backend interface.
var _plugin: Object
var _id := 0

func open(_window: int, _display: int, _server: String, _profile: String) -> String:
	if not Engine.has_singleton("WebFrameAndroid"):
		return "Android WebFrame plugin is missing. Enable Gradle Build in the Android export preset."
	_plugin = Engine.get_singleton("WebFrameAndroid")
	_id = _plugin.create_view()
	return "" if _id > 0 else "Android WebFrame could not reserve a browser instance."

func close() -> void:
	if _plugin != null and _id > 0:
		_plugin.destroy_view(_id)
	_id = 0
	_plugin = null

func set_bounds(rect: Rect2i) -> void:
	_plugin.set_view_bounds(_id, rect.position.x, rect.position.y, rect.size.x, rect.size.y)

func set_visible(value: bool) -> void:
	_plugin.set_view_visible(_id, value)

func set_transparent(value: bool) -> void:
	_plugin.set_view_transparent(_id, value)

func navigate(address: String) -> void:
	_plugin.navigate_view(_id, address)

func load_html(html: String) -> void:
	_plugin.load_view_html(_id, html)

func evaluate(script: String) -> void:
	_plugin.evaluate_view(_id, script)

func pump() -> void:
	pass

func poll() -> Array:
	var parser := JSON.new()
	if parser.parse(_plugin.poll_view(_id)) != OK or not parser.data is Array:
		return []
	return parser.data
