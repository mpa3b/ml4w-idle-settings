#!/usr/bin/env bash
#
# Uninstall the Idle timers panel
#

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/ml4w-idle-settings"
BIN_LINK="$HOME/.local/bin/ml4w-idle-settings"

if pgrep -f "^qs -p ${INSTALL_DIR}$" >/dev/null 2>&1; then
    echo ":: Stopping the running idle panel"
    pkill -f "^qs -p ${INSTALL_DIR}$" || true
fi

if [ -L "$BIN_LINK" ]; then
    echo ":: Removing $BIN_LINK"
    rm -f "$BIN_LINK"
fi

if [ -d "$INSTALL_DIR" ]; then
    echo ":: Removing $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
    echo ":: Done."
else
    echo ":: Nothing to do: $INSTALL_DIR does not exist."
fi

echo ":: hypridle.conf and your Hyprland keybinding were kept."
