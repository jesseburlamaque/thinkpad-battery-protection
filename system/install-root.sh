#!/usr/bin/bash

set -euo pipefail

if (( EUID != 0 )); then
  echo "This installer requires root privileges" >&2
  exit 77
fi

initial_stop="${1:-85}"
initial_start="${2:-75}"
source_dir="${3:-}"

if [[ -z $source_dir || ! -d $source_dir ]]; then
  echo "Source directory must be provided: $source_dir" >&2
  exit 64
fi

install -d -m 0755 /usr/local/libexec
install -d -m 0755 /etc/systemd/system
install -d -m 0755 /etc/polkit-1/rules.d

install -m 0755 "$source_dir/system/tbp-helper" /usr/local/libexec/tbp-helper
install -m 0755 "$source_dir/system/tbp-set" /usr/local/libexec/tbp-set
install -m 0755 "$source_dir/system/tbp-uninstall" /usr/local/libexec/tbp-uninstall
install -m 0644 "$source_dir/system/thinkpad-battery-protection.service" /etc/systemd/system/thinkpad-battery-protection.service
install -m 0644 "$source_dir/system/49-thinkpad-battery-protection.rules" /etc/polkit-1/rules.d/49-thinkpad-battery-protection.rules

# If configuration does not exist, initialize it
if [[ ! -f /etc/thinkpad-battery-protection.conf ]]; then
  /usr/local/libexec/tbp-helper set "$initial_stop" "$initial_start"
else
  /usr/local/libexec/tbp-helper apply
fi

systemctl daemon-reload
systemctl enable --now thinkpad-battery-protection.service

echo "ThinkPad Battery Protection installed and enabled successfully."
