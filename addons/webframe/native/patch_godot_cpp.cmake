# Godot 4.4's macOS configuration also runs on iOS, where Cocoa does not exist.
# Keep the iOS sysroot and skip the macOS-only framework lookup.
set(config "${GODOT_CPP_SOURCE}/cmake/macos.cmake")
file(READ "${config}" contents)
string(REPLACE "IF(APPLE)" "IF(APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL \"iOS\")" contents "${contents}")
file(WRITE "${config}" "${contents}")
