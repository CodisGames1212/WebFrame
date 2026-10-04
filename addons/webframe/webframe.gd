@tool
extends EditorPlugin
var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	var icon := Image.new()
	icon.load_svg_from_string(FileAccess.get_file_as_string("res://addons/webframe/icon.svg"))
	add_custom_type("WebFrame", "Control", preload("res://addons/webframe/web_frame.gd"), ImageTexture.create_from_image(icon))
	_export_plugin = preload("res://addons/webframe/mobile/export_plugin.gd").new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
	remove_custom_type("WebFrame")
