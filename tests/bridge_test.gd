extends SceneTree

const Frame = preload("res://addons/webframe/web_frame.gd")
var calls := 0
var messages := 0

func _initialize() -> void:
	var frame := Frame.new()
	frame.bridge_origins = PackedStringArray(["https://trusted.example", "null"])
	frame.bind_js("sum", func(a, b):
		calls += 1
		return a + b)
	frame.message_received.connect(func(_value): messages += 1)
	var packet := JSON.stringify({"kind": "call", "id": "1", "method": "sum", "args": [20, 22]})
	frame._dispatch(packet, "https://evil.example/")
	assert(calls == 0, "Untrusted origin reached bound method")
	frame._dispatch(packet, "https://trusted.example/path")
	assert(calls == 1)
	frame.unbind_js("sum")
	frame._dispatch(packet, "https://trusted.example/path")
	assert(calls == 1)
	frame._dispatch("{bad json", "about:blank")
	frame._dispatch(JSON.stringify({"kind": "call", "id": {}, "args": []}), "about:blank")
	frame._dispatch(JSON.stringify({"kind": "message", "data": {"ok": true}}), "about:blank")
	assert(messages == 1)
	frame._dispatch(JSON.stringify({"kind": "message", "data": "Android inline HTML"}), "null")
	assert(messages == 2, "Android opaque origin should match the explicit null allowlist")
	assert(not frame.call_js("1+1"))
	frame.free()
	print("PASS: bridge allowlist, explicit binding, malformed messages, unavailable browser")
	quit()
