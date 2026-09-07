#!/usr/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
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

"$script_dir/menu.sh" install

if (( menu_only )); then
  echo "Menu entry installed."
  exit 0
fi

pkexec "$script_dir/system/install-root.sh" "$initial_stop" "$initial_start" "$script_dir"
