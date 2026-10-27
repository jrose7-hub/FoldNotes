#!/bin/bash
# Builds ComprimiNote.app from the source, on your own Mac.
# Needs only the Xcode command line tools (xcode-select --install).
# Usage: ./build.sh   →   creates build/ComprimiNote.app
set -euo pipefail
cd "$(dirname "$0")"

APP=build/ComprimiNote.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ Compiling…"
swiftc -O ComprimiNote.swift -o "$APP/Contents/MacOS/ComprimiNote"
cp Info.plist "$APP/Contents/Info.plist"

# Icon (optional): AppIcon.png, square, ideally 1024×1024
if [ -f AppIcon.png ]; then
	echo "→ Icon…"
	SET=build/AppIcon.iconset
	mkdir -p "$SET"
	for s in 16 32 128 256 512; do
		sips -z $s $s AppIcon.png --out "$SET/icon_${s}x${s}.png" >/dev/null
		sips -z $((s * 2)) $((s * 2)) AppIcon.png --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
	done
	iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"
	rm -rf "$SET"
fi

# Local signature with "hardened runtime": blocks code injection.
# It's a signature valid only on your Mac (no Apple developer account).
echo "→ Signing…"
codesign --force --options runtime -s - "$APP"
codesign --verify --deep --strict "$APP"

echo
echo "Done: $APP"
echo "App fingerprint (note it down):"
codesign -dv --verbose=4 "$APP" 2>&1 | grep '^CDHash='
