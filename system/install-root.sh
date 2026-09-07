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

install -m 0755 "$source_dir/system/thinkcharge-helper" /usr/local/libexec/thinkcharge-helper
install -m 0755 "$source_dir/system/thinkcharge-set" /usr/local/libexec/thinkcharge-set
install -m 0755 "$source_dir/system/thinkcharge-uninstall" /usr/local/libexec/thinkcharge-uninstall
install -m 0644 "$source_dir/system/thinkcharge.service" /etc/systemd/system/thinkcharge.service
install -m 0644 "$source_dir/system/49-thinkcharge.rules" /etc/polkit-1/rules.d/49-thinkcharge.rules

# If configuration does not exist, initialize it
if [[ ! -f /etc/thinkcharge.conf ]]; then
  /usr/local/libexec/thinkcharge-helper set "$initial_stop" "$initial_start"
else
  /usr/local/libexec/thinkcharge-helper apply
fi

systemctl daemon-reload
systemctl enable --now thinkcharge.service

echo "ThinkCharge installed and enabled successfully."
