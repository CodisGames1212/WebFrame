@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "WebFrameMobile"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid

func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(["webframe/bin/android/webframe-release.aar"])

func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(["androidx.webkit:webkit:1.12.1"])

func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	return '<uses-permission android:name="android.permission.INTERNET" />'
