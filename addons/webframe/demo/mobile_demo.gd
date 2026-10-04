extends Control

const Frame = preload("res://addons/webframe/web_frame.gd")
var frame: Control
var status: Label
var address: LineEdit

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "WebFrame · mobile"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var navigation := HBoxContainer.new()
	column.add_child(navigation)
	address = LineEdit.new()
	address.placeholder_text = "https://example.com"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.text_submitted.connect(_navigate)
	navigation.add_child(address)
	_button(navigation, "Go", func(): _navigate(address.text))
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_button(actions, "Back", func(): frame.go_back())
	_button(actions, "Local", _local_demo)
	_button(actions, "Call JS", func(): frame.call_js("document.querySelector('#from-godot').textContent='Hello from mobile Godot!'"))
	status = Label.new()
	status.text = "Starting browser…"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	frame = Frame.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.bridge_origins = PackedStringArray(["null"])
	frame.bind_js("greet", func(name): return "Hello, %s! Sent from mobile GDScript." % str(name))
	frame.error.connect(func(problem): status.text = str(problem))
	frame.load_finished.connect(func(loaded): status.text = "Loaded: " + str(loaded))
	_local_demo()
	column.add_child(frame)

func _button(parent: Control, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	parent.add_child(button)

func _navigate(value: String) -> void:
	if not value.contains("://"):
		value = "https://" + value
	frame.navigate(value)

func _local_demo() -> void:
	frame.load_html(FileAccess.get_file_as_string("res://addons/webframe/index.html"))
