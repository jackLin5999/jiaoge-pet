#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

pkill -f "ClaudePet.app/Contents/MacOS/ClaudePet" 2>/dev/null || true
./build.sh
open "build/ClaudePet.app"
