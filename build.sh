#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/JiaoGe.app"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

# 皇冠素材
if [ -d Resources ]; then cp -R Resources/. "${APP}/Contents/Resources/"; fi

# 编译。默认只编本机架构（快）；ARCHS=universal 时编 arm64 + x86_64 再合并，供发布用
SOURCES=(Sources/main.swift Sources/Features.swift)
FLAGS=(-framework AppKit -framework QuartzCore)
ARCHS="${ARCHS:-$(uname -m)}"
if [ "$ARCHS" = "universal" ]; then
    TMP="$(mktemp -d)"
    # 命令行工具里的 Swift 兼容库只有 arm64，交叉编译 x86_64 会失败；失败就退回本机架构
    if swiftc -O -target arm64-apple-macos12.0 -o "$TMP/arm64" "${SOURCES[@]}" "${FLAGS[@]}" 2>/dev/null \
       && swiftc -O -target x86_64-apple-macos12.0 -o "$TMP/x86_64" "${SOURCES[@]}" "${FLAGS[@]}" 2>/dev/null \
       && lipo -create -output "${APP}/Contents/MacOS/JiaoGe" "$TMP/arm64" "$TMP/x86_64" 2>/dev/null; then
        echo "universal binary: $(lipo -archs "${APP}/Contents/MacOS/JiaoGe")"
    else
        echo "⚠️ 没能生成通用二进制（命令行工具缺 x86_64 的 Swift 兼容库，装完整 Xcode 才行）"
        echo "   退回本机架构：$(uname -m)"
        swiftc -O -o "${APP}/Contents/MacOS/JiaoGe" "${SOURCES[@]}" "${FLAGS[@]}"
    fi
    rm -rf "$TMP"
else
    swiftc -O -o "${APP}/Contents/MacOS/JiaoGe" "${SOURCES[@]}" "${FLAGS[@]}"
fi

cat > "${APP}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>蕉哥</string>
    <key>CFBundleDisplayName</key><string>蕉哥</string>
    <key>CFBundleExecutable</key><string>JiaoGe</string>
    <key>CFBundleIdentifier</key><string>local.jiaoge.pet</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSUIElement</key><true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key><true/>
    </dict>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
</dict>
</plist>
PLIST

# 优先用固定的自签名身份：这样重新编译签名不变，屏幕录制授权不会失效
IDENTITY="JiaoGe Local Signing"
if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    codesign --force --deep -s "$IDENTITY" "${APP}" >/dev/null 2>&1 \
        || codesign --force --deep -s - "${APP}" >/dev/null 2>&1 || true
    echo "signed with: $IDENTITY"
else
    codesign --force --deep -s - "${APP}" >/dev/null 2>&1 || true
    echo "signed: ad-hoc（没找到固定证书，重启后屏幕录制授权可能失效）"
fi
echo "built: ${APP}"
