#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
zsh scripts/fetch-runtime.zsh
swift build -c release
install_app="$PWD/dist/kanbanana.app"
# Sign outside Documents: its cloud provider can immediately reattach FinderInfo
# to a bundle there, racing codesign even after xattr removes the metadata.
stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/kanbanana-build.XXXXXX")
trap 'rm -rf "$stage_dir"' EXIT
app="$stage_dir/kanbanana.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/AgentKanban "$app/Contents/MacOS/kanbanana"
cp Resources/reader.py "$app/Contents/Resources/reader.py"
mkdir -p "$app/Contents/Resources/kanbanana_reader"
cp Resources/kanbanana_reader/*.py "$app/Contents/Resources/kanbanana_reader/"
ditto --norsrc --noextattr .build/runtime/python "$app/Contents/Resources/Python"
cp -R Resources/Branding "$app/Contents/Resources/Branding"
cp -R Resources/PythonLicenses "$app/Contents/Resources/PythonLicenses"
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
iconset="$stage_dir/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z $size $size Resources/Branding/banana.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double Resources/Branding/banana.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
if [[ -d Resources/Photos ]]; then
    mkdir -p "$app/Contents/Resources/Photos"
    cp Resources/Photos/*.{png,jpg,json,md}(N) "$app/Contents/Resources/Photos/"
fi
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>kanbanana</string>
<key>CFBundleIdentifier</key><string>com.laurenceholt.agent-kanban</string>
<key>CFBundleName</key><string>kanbanana</string>
<key>CFBundleDisplayName</key><string>kanbanana</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>3</string>
<key>CFBundleShortVersionString</key><string>0.3.0-beta.1</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Verify the complete staged bundle before copying it into the workspace.
xattr -cr "$app"
sign_identity=${KANBAN_SIGN_IDENTITY:--}
sign_options=()
if [[ $sign_identity != - ]]; then sign_options=(--options runtime --timestamp); fi
# Sign embedded executable code inside-out, including the Python runtime.
while IFS= read -r -d '' binary; do
    if /usr/bin/file -b "$binary" | /usr/bin/grep -q 'Mach-O'; then
        codesign --force --sign "$sign_identity" "${sign_options[@]}" "$binary"
    fi
done < <(find "$app/Contents/Resources/Python" -type f -print0)
codesign --force --sign "$sign_identity" "${sign_options[@]}" "$app"
codesign --verify --deep --strict "$app"
mkdir -p "${install_app:h}"
ditto --norsrc --noextattr "$app" "$install_app"
print -r -- "Built $install_app"
