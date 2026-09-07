#!/usr/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly PLUGIN_ID="jesseburlamaque.thinkpad-battery-protection"
readonly TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"

if (( EUID == 0 )); then
  echo "Run uninstall.sh as the desktop user, without sudo" >&2
  exit 64
fi

echo "==> Removing Omarchy menu entry..."
"$script_dir/menu.sh" remove

if [[ -x /usr/local/libexec/tbp-uninstall ]]; then
  echo "==> Removing system components (privileged helper, systemd service, polkit rule)..."
  pkexec /usr/local/libexec/tbp-uninstall
fi

# Clean up symlink if it was installed as a link
if [[ -L "$TARGET_DIR" ]]; then
  echo "==> Removing plugin symlink from $TARGET_DIR..."
  rm -f "$TARGET_DIR"
fi

echo "==> Refreshing Omarchy shell..."
if command -v omarchy-shell &>/dev/null; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi

echo ""
echo "✓ ThinkPad Battery Protection uninstalled successfully."
echo "  Note: If you added the plugin via 'omarchy plugin add', you can also remove the files with:"
echo "        omarchy plugin remove $PLUGIN_ID"
