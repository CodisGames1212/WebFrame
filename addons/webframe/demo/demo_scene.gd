extends Control

const Frame = preload("res://addons/webframe/web_frame.gd")
const DEMO_HTML_PATH: String = "res://addons/webframe/index.html"

var frame: Frame
var status: Label
var address: LineEdit


func _ready() -> void:
	if OS.has_feature("webframe_smoke"):
		get_tree().change_scene_to_file.call_deferred("res://tests/mobile_smoke.tscn")
		return
	if OS.get_name() in ["Android", "iOS"]:
		get_tree().change_scene_to_file.call_deferred("res://addons/webframe/demo/mobile_demo.tscn")
		return

	var background: ColorRect = ColorRect.new()
	background.color = Color("101923")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title: Label = Label.new()
	title.text = "WebFrame  /  native web for Godot"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("76d6c5"))
	column.add_child(title)

	var toolbar: HBoxContainer = HBoxContainer.new()
	column.add_child(toolbar)
	_button(toolbar, "←", func() -> void: frame.go_back())
	_button(toolbar, "→", func() -> void: frame.go_forward())
	_button(toolbar, "Reload", func() -> void: frame.reload())

	address = LineEdit.new()
	address.placeholder_text = "https://example.com"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.text_submitted.connect(_navigate)
	toolbar.add_child(address)
	_button(toolbar, "Go", func() -> void: _navigate(address.text))
	_button(toolbar, "Local demo", _local_demo)
	_button(toolbar, "Call JS", _call_javascript)

	status = Label.new()
	status.text = "Starting native browser…"
	column.add_child(status)

	frame = Frame.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(320, 240)
	frame.bridge_origins = PackedStringArray(["null"])
	frame.bind_js("greet", func(name: Variant) -> String:
		status.text = "JavaScript called GDScript: " + str(name)
		return "Hello, %s! This reply came from Godot." % str(name))
	frame.browser_ready.connect(func() -> void: status.text = "Native browser ready")
	frame.load_finished.connect(func(loaded_url: String) -> void: status.text = "Loaded: " + loaded_url)
	frame.error.connect(func(problem: String) -> void: status.text = problem)
	column.add_child(frame)
	_local_demo()


func _button(parent: Control, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func _navigate(value: String) -> void:
	var target: String = value.strip_edges()
	if target.is_empty():
		return
	if not target.contains("://"):
		target = "https://" + target
	frame.navigate(target)


func _local_demo() -> void:
	if not FileAccess.file_exists(DEMO_HTML_PATH):
		status.text = "Demo HTML file not found: " + DEMO_HTML_PATH
		push_error(status.text)
		return
	frame.load_html(FileAccess.get_file_as_string(DEMO_HTML_PATH))


func _call_javascript() -> void:
	frame.call_js("const target=document.querySelector('#from-godot');if(target)target.textContent='Hello from GDScript at '+new Date().toLocaleTimeString()")
