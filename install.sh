#!/bin/bash
# Installs ComprimiNote (already built with ./build.sh) in /Applications.
# It asks for the administrator password: the app becomes system-owned,
# so no program can modify it without your password.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/ComprimiNote.app
[ -d "$APP" ] || { echo "Run ./build.sh first"; exit 1; }

pkill -f "ComprimiNote.app/Contents/MacOS" 2>/dev/null || true
sudo rm -rf /Applications/ComprimiNote.app
sudo ditto "$APP" /Applications/ComprimiNote.app
sudo chown -R root:wheel /Applications/ComprimiNote.app
sudo chmod -R go-w /Applications/ComprimiNote.app

# Start at login (macOS may ask to allow control of "System Events")
osascript -e 'tell application "System Events" to delete (every login item whose name is "ComprimiNote")' 2>/dev/null || true
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/ComprimiNote.app", hidden:true}' >/dev/null

echo
echo "Installed. Now:"
echo "1. In System Settings › Privacy & Security › Accessibility"
echo "   (on macOS 27: \"Device control and data access\")"
echo "   turn on ComprimiNote. If it's already there from a previous version,"
echo "   remove it with – and add it again with +."
echo "2. Start it: open /Applications/ComprimiNote.app"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
