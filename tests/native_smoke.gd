extends SceneTree

const Frame = preload("res://addons/webframe/web_frame.gd")
var frame: Control
var done := false
var method_called := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Destroy a browser while asynchronous Windows initialization is still pending.
	var temporary := Frame.new()
	root.add_child(temporary)
	temporary.free()
	frame = Frame.new()
	frame.position = Vector2(30, 40)
	frame.size = Vector2(600, 400)
	frame.bridge_origins = PackedStringArray(["null"])
	frame.transparent_background = true
	frame.bind_js("sum", func(a, b):
		method_called = true
		return a + b)
	frame.error.connect(_fail)
	frame.load_finished.connect(func(_url):
		frame.call_js("(async()=>{const result=await WebFrame.call('sum',20,22);WebFrame.postMessage({result,marker:'smoke'});})()"))
	frame.message_received.connect(_message)
	frame.load_html("<!doctype html><html><body><h1>WebFrame smoke test</h1></body></html>")
	root.add_child(frame)
	await create_timer(25).timeout
	if not done:
		_fail("Timed out waiting for native JavaScript bridge")

func _message(value: Variant) -> void:
	if done:
		return
	if not value is Dictionary or value.get("result") != 42 or not method_called:
		_fail("Native bridge returned unexpected data")
		return
	frame.size = Vector2(480, 320)
	frame.hide()
	await process_frame
	frame.show()
	await process_frame
	frame.free()
	done = true
	print("PASS: native HTML load, JS -> GDScript -> JS, transparency setup, resize, visibility, pending initialization teardown")
	quit()

func _fail(problem: String) -> void:
	if done:
		return
	done = true
	printerr("FAIL: " + problem)
	quit(1)
