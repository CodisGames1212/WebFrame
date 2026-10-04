#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cmake -S addons/webframe/native -B addons/webframe/native/build-macos -DCMAKE_BUILD_TYPE=Release '-DCMAKE_OSX_ARCHITECTURES=arm64;x86_64' -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0
cmake --build addons/webframe/native/build-macos --parallel "${WEBFRAME_JOBS:-4}"
lipo -info addons/webframe/bin/webframe.macos.universal.dylib
otool -L addons/webframe/bin/webframe.macos.universal.dylib
