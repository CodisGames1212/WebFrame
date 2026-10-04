#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cmake -S addons/webframe/native -B addons/webframe/native/build-linux -DCMAKE_BUILD_TYPE=Release
cmake --build addons/webframe/native/build-linux --parallel "${WEBFRAME_JOBS:-4}"
ldd addons/webframe/bin/webframe.linux.*.so
