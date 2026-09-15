#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SUPPORT_DIR="$HOME/Library/Application Support/AzureVPNMenuBar"
BINARY_PATH="$APP_SUPPORT_DIR/AzureVPNMenuBar"
LABEL="com.arsenedesalme.azurevpnmenubar"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "==> Compilation..."
mkdir -p "$APP_SUPPORT_DIR"
swiftc -O "$SCRIPT_DIR/VPNMenuBar.swift" -o "$BINARY_PATH"

echo "==> Ecriture du LaunchAgent..."
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$APP_SUPPORT_DIR/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$APP_SUPPORT_DIR/stderr.log</string>
</dict>
</plist>
EOF

echo "==> (Re)chargement du LaunchAgent..."
launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "==> Installe. L'icone VPN devrait apparaitre dans la barre de menu."
echo "    Binaire   : $BINARY_PATH"
echo "    LaunchAgent: $PLIST_PATH"
echo "    Logs       : $APP_SUPPORT_DIR/std{out,err}.log"
