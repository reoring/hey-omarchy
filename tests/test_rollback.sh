#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
bindir="$tmp/bin"
mkdir -p "$home" "$bindir"
omarchy_root="$tmp/omarchy"
mkdir -p "$omarchy_root/default/hypr"
printf '%s\n' "-- native configuration fixture" >"$omarchy_root/default/hypr/bootstrap.lua"

write_stub() {
  local name="$1"
  local body="$2"
  local path="$bindir/$name"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -euo pipefail'
    printf '%s\n' "$body"
  } >"$path"
  chmod +x "$path"
}

write_stub systemctl 'exit 0'
write_stub hyprctl 'case "${1:-}" in monitors) printf "%s\n" "[]" ;; *) exit 0 ;; esac'
write_stub notify-send 'exit 0'
write_stub omarchy 'exit 0'
write_stub sudo 'exit 0'
write_stub ldconfig 'exit 0'

mkdir -p "$home/.config/hypr"
printf '%s\n' "-- original custom module" >"$home/.config/hypr/hey-omarchy.lua"
printf '%s\n' "-- original user entrypoint" >"$home/.config/hypr/hyprland.lua"
printf '%s\n' "-- independent user input settings" >"$home/.config/hypr/input.lua"
cp "$home/.config/hypr/hey-omarchy.lua" "$tmp/original-module"
cp "$home/.config/hypr/hyprland.lua" "$tmp/original-entrypoint"
cp "$home/.config/hypr/input.lua" "$tmp/original-input"

HOME="$home" OMARCHY_PATH="$omarchy_root" PATH="$bindir:$PATH" bash ./apply.sh --skip-packages --no-bar --no-gtk-gsettings --skip-nvidia-env >/dev/null

if cmp -s "$tmp/original-module" "$home/.config/hypr/hey-omarchy.lua"; then
  printf '%s\n' "expected the bundled customization module to be installed" >&2
  exit 1
fi
if ! cmp -s "$tmp/original-input" "$home/.config/hypr/input.lua"; then
  printf '%s\n' "apply must preserve unrelated user input settings" >&2
  exit 1
fi

set +e
out=$(HOME="$home" PATH="$bindir:$PATH" bash ./rollback.sh 2>&1)
st=$?
set -e

if [[ $st -ne 0 ]]; then
  printf '%s\n' "expected: rollback exit 0" >&2
  printf '%s\n' "actual:   exit $st" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi

if ! cmp -s "$tmp/original-module" "$home/.config/hypr/hey-omarchy.lua" \
  || ! cmp -s "$tmp/original-entrypoint" "$home/.config/hypr/hyprland.lua"; then
  printf '%s\n' "expected rollback to restore module and user entrypoint" >&2
  exit 1
fi

printf '%s\n' "PASS: rollback restores Quattro customizations"
