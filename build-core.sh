#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/Core"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
./build/AndroidRuntimeCoreSmokeTest
