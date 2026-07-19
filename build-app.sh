#!/bin/zsh
set -euo pipefail

cd "${0:A:h}"
export CLANG_MODULE_CACHE_PATH="/tmp/bypass-router-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
export XDG_CACHE_HOME="/tmp/bypass-router-swift-cache"
swift build --disable-sandbox -c release

app_dir="build/旁路由助手.app"
if [[ -d "$app_dir" ]]; then
    rm -rf "$app_dir"
fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/SourceArchive"
cp ".build/release/BypassRouter" "$app_dir/Contents/MacOS/BypassRouter"
cp "Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "Resources/network-helper.sh" "$app_dir/Contents/Resources/network-helper.sh"
cp "Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
cp "Package.swift" "$app_dir/Contents/Resources/SourceArchive/Package.swift"
ditto "Sources" "$app_dir/Contents/Resources/SourceArchive/Sources"
ditto "Resources" "$app_dir/Contents/Resources/SourceArchive/Resources"
ditto "Tests" "$app_dir/Contents/Resources/SourceArchive/Tests"
cp "ARCHITECTURE.md" "$app_dir/Contents/Resources/SourceArchive/ARCHITECTURE.md"
cp "AUDIT.md" "$app_dir/Contents/Resources/SourceArchive/AUDIT.md"
chmod +x "$app_dir/Contents/MacOS/BypassRouter" "$app_dir/Contents/Resources/network-helper.sh"
codesign --force --deep --sign - "$app_dir"
print "$app_dir"
