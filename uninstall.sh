#!/usr/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if (( EUID == 0 )); then
  echo "Run uninstall.sh as the desktop user, without sudo" >&2
  exit 64
fi

"$script_dir/menu.sh" remove

if [[ -x /usr/local/libexec/tbp-uninstall ]]; then
  pkexec /usr/local/libexec/tbp-uninstall
fi

echo "ThinkPad Battery Protection uninstalled."
