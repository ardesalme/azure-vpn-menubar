#!/bin/bash
set -euo pipefail

LABEL="com.arsenedesalme.azurevpnmenubar"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
APP_SUPPORT_DIR="$HOME/Library/Application Support/AzureVPNMenuBar"

launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"
rm -rf "$APP_SUPPORT_DIR"

echo "==> Desinstalle."
