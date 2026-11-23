#!/usr/bin/env bash
#
# Install or update the Idle timers panel for Hyprland
#

set -euo pipefail

REPO_URL="${IDLE_SETTINGS_REPO:-https://github.com/mpa3b/ml4w-idle-settings.git}"
INSTALL_DIR="$HOME/.local/share/ml4w-idle-settings"
BIN_DIR="$HOME/.local/bin"

for tool in git qs python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo ":: ERROR: $tool is required but not installed."
        exit 1
    fi
done

if [ -d "$INSTALL_DIR/.git" ]; then
    echo ":: Updating ml4w-idle-settings in $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
    echo ":: ml4w-idle-settings updated successfully."
elif [ -d "$INSTALL_DIR" ]; then
    echo ":: ERROR: $INSTALL_DIR exists but is not a git repository."
    echo ":: Please remove or rename it and run this script again."
    exit 1
else
    echo ":: Cloning ml4w-idle-settings into $INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    if ! git clone "$REPO_URL" "$INSTALL_DIR"; then
        echo ":: ERROR: could not clone $REPO_URL"
        echo ":: The repository is private. Authenticate git with GitHub first:"
        echo "::   gh auth login && gh auth setup-git"
        exit 1
    fi
    echo ":: ml4w-idle-settings installed successfully."
fi

echo ":: Linking ml4w-idle-settings into $BIN_DIR"
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/bin/ml4w-idle-settings" "$BIN_DIR/ml4w-idle-settings"

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo ":: WARNING: $BIN_DIR is not in your \$PATH."
        echo ":: Add it to your shell configuration, e.g. in ~/.bashrc or ~/.zshrc:"
        echo ':: export PATH="$HOME/.local/bin:$PATH"'
        ;;
esac

echo ":: Start the panel with: ml4w-idle-settings"
echo ":: See $INSTALL_DIR/README.md for the Hyprland keybinding and autostart."
