extends Control

const Frame = preload("res://addons/webframe/web_frame.gd")
var frame: Control
var complete := false
var called := false

func _ready() -> void:
	print("WEBFRAME_MOBILE_SMOKE_START " + OS.get_name())
	frame = Frame.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.bridge_origins = PackedStringArray(["null"])
	frame.transparent_background = true
	frame.bind_js("sum", func(a, b):
		called = true
		return a + b)
	frame.error.connect(_fail)
	frame.load_finished.connect(func(_url): frame.call_js("(async()=>{const result=await WebFrame.call('sum',20,22);WebFrame.postMessage({result});})()"))
	frame.message_received.connect(_message)
	frame.load_html("<!doctype html><html><body style='background:transparent'><h1>Mobile WebFrame test</h1><input placeholder='Native keyboard test'></body></html>")
	add_child(frame)
	await get_tree().create_timer(45).timeout
	if not complete:
		_fail("Timed out waiting for mobile native bridge")

func _message(value: Variant) -> void:
	if complete:
		return
	if not value is Dictionary or value.get("result") != 42 or not called:
		_fail("Unexpected mobile bridge response")
		return
	frame.hide()
	await get_tree().process_frame
	frame.show()
	frame.size *= 0.8
	await get_tree().process_frame
	frame.free()
	complete = true
	print("WEBFRAME_MOBILE_SMOKE_PASS " + OS.get_name())

func _fail(problem: String) -> void:
	if not complete:
		complete = true
		printerr("WEBFRAME_MOBILE_SMOKE_FAIL " + problem)
