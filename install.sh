#!/bin/bash
# Installs FoldNotes (already built with ./build.sh) in /Applications.
# It asks for the administrator password: the app becomes system-owned,
# so no program can modify it without your password.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/FoldNotes.app
[ -d "$APP" ] || { echo "Run ./build.sh first"; exit 1; }

pkill -f "FoldNotes.app/Contents/MacOS" 2>/dev/null || true
sudo rm -rf /Applications/FoldNotes.app
sudo ditto "$APP" /Applications/FoldNotes.app
sudo chown -R root:wheel /Applications/FoldNotes.app
sudo chmod -R go-w /Applications/FoldNotes.app

# Start at login (macOS may ask to allow control of "System Events")
osascript -e 'tell application "System Events" to delete (every login item whose name is "FoldNotes")' 2>/dev/null || true
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/FoldNotes.app", hidden:true}' >/dev/null

echo
echo "Installed. Now:"
echo "1. In System Settings › Privacy & Security › Accessibility"
echo "   (on macOS 27: \"Device control and data access\")"
echo "   turn on FoldNotes. If it's already there from a previous version,"
echo "   remove it with – and add it again with +."
echo "2. Start it: open /Applications/FoldNotes.app"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
