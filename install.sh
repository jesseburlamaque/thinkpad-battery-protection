#!/usr/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly PLUGIN_ID="jesseburlamaque.thinkpad-battery-protection"
readonly TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"

menu_only=0
if [[ ${1:-} == "--menu-only" ]]; then
  menu_only=1
  initial_stop=85
  initial_start=75
else
  initial_stop="${1:-85}"
  initial_start="${2:-75}"
fi

if [[ ! $initial_stop =~ ^[0-9]+$ ]] || (( initial_stop < 40 || initial_stop > 100 )); then
  echo "Stop charge limit must be an integer from 40 to 100" >&2
  exit 64
fi

if [[ ! $initial_start =~ ^[0-9]+$ ]] || (( initial_start < 0 || initial_start > 95 )); then
  echo "Start charge limit must be an integer from 0 to 95" >&2
  exit 64
fi

if (( initial_start >= initial_stop )); then
  initial_start=$(( initial_stop - 5 ))
fi

if (( EUID == 0 )); then
  echo "Run install.sh as the desktop user, without sudo" >&2
  exit 64
fi

# If executed outside Omarchy's plugins directory (e.g. manual git clone),
# link it automatically so Omarchy discovers the plugin.
if [[ "$script_dir" != "$TARGET_DIR" && ! -e "$TARGET_DIR" ]]; then
  mkdir -p "$(dirname "$TARGET_DIR")"
  ln -s "$script_dir" "$TARGET_DIR"
  echo "==> Linked plugin into Omarchy plugins directory: $TARGET_DIR"
fi

echo "==> Configuring Omarchy menu (Trigger > Hardware)..."
"$script_dir/menu.sh" install

if (( menu_only )); then
  echo "Menu entry installed."
  exit 0
fi

echo ""
echo "==> Installing system components with administrator privileges:"
echo "    - Helper tools:    /usr/local/libexec/tbp-helper, tbp-set"
echo "    - Systemd service: /etc/systemd/system/thinkpad-battery-protection.service"
echo "    - Polkit rule:     /etc/polkit-1/rules.d/49-thinkpad-battery-protection.rules"
echo "    - Initial config:  /etc/thinkpad-battery-protection.conf ($initial_stop% stop, $initial_start% start)"
echo ""

pkexec "$script_dir/system/install-root.sh" "$initial_stop" "$initial_start" "$script_dir"

echo "==> Refreshing Omarchy shell..."
if command -v omarchy-shell &>/dev/null; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi
if command -v omarchy &>/dev/null; then
  omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 || true
fi

echo ""
echo "✓ ThinkPad Battery Protection installed successfully!"
echo "  - Open from menu:   Trigger → Hardware → ThinkPad Battery Protection"
echo "  - Open via command:  omarchy-shell $PLUGIN_ID open"
echo "  - To uninstall:      $script_dir/uninstall.sh"
