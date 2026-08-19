#!/usr/bin/env bash
# 在 Codespace / Linux 上构建 Qt demo
set -euo pipefail
cd "$(dirname "$0")"

cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
echo "==> 构建完成: build/mms1e-qt-demo"
