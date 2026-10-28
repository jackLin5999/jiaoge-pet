#!/bin/bash
# 打发布包：通用二进制（能编就编）+ zip
set -euo pipefail
cd "$(dirname "$0")"

ARCHS=universal ./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "build/JiaoGe.app/Contents/Info.plist")
OUT="build/JiaoGe-${VERSION}.zip"
rm -f "$OUT"

# 打包时带上给使用者的说明
STAGE="build/release-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R build/JiaoGe.app "$STAGE/"
if [ -f INSTALL.md ]; then
    # 在压缩包里放一份纯文本版，解压就能看到
    sed -e 's/^# \{1,6\} //' -e 's/`//g' -e 's/\*\*//g' INSTALL.md > "$STAGE/安装说明.txt"
fi
ditto -c -k --norsrc --noextattr "$STAGE" "$OUT"
rm -rf "$STAGE"

echo
echo "发布包: $OUT"
echo "大小: $(du -h "$OUT" | cut -f1)"
echo "架构: $(lipo -archs build/JiaoGe.app/Contents/MacOS/JiaoGe)"
