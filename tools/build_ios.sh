#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cmake -S addons/webframe/native -B addons/webframe/native/build-ios -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build addons/webframe/native/build-ios --config Release --parallel "${WEBFRAME_JOBS:-4}"
otool -L addons/webframe/bin/webframe.ios.arm64.dylib
