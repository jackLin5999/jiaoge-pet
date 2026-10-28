#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

pkill -f "JiaoGe.app/Contents/MacOS/JiaoGe" 2>/dev/null || true
./build.sh
open "build/JiaoGe.app"
