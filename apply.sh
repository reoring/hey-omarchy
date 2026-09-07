#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_HOME="$ROOT/home"
OMARCHY_ROOT="${OMARCHY_PATH:-/usr/share/omarchy}"

DRY_RUN=0
NO_BAR=0
WITH_SHADERS=0
FORCE_MONITORS=0
FORCE_NVIDIA_ENV=0
SKIP_NVIDIA_ENV=0
CHECK_ONLY=0
SKIP_PACKAGES=0
APPLY_GTK_GSETTINGS=1

usage() {
  cat <<'EOF'
Usage: apply.sh [options]

Options:
  --check              Print environment/repo checks and exit
  --dry-run            Print actions without changing files
  --skip-packages      Skip package install via yay
  --gtk-gsettings       Also set GTK prefs via gsettings (Emacs keys + button layout) [default]
  --no-gtk-gsettings    Do not touch GTK gsettings
  --no-bar             Skip Quattro shell widgets and idle settings
  --with-shaders       Symlink ~/.config/hypr/shaders from /usr/share/aether/shaders
  --force-monitors     Apply bundled hardware-specific monitor settings
  --force-nvidia-env   Apply NVIDIA environment settings
  --skip-nvidia-env    Never apply NVIDIA environment settings
  -h, --help           Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --skip-packages) SKIP_PACKAGES=1 ;;
    --gtk-gsettings) APPLY_GTK_GSETTINGS=1 ;;
    --no-gtk-gsettings) APPLY_GTK_GSETTINGS=0 ;;
    --no-bar) NO_BAR=1 ;;
    --with-shaders) WITH_SHADERS=1 ;;
    --force-monitors) FORCE_MONITORS=1 ;;
    --force-nvidia-env) FORCE_NVIDIA_ENV=1 ;;
    --skip-nvidia-env) SKIP_NVIDIA_ENV=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

log() {
  printf '%s\n' "$*" >&2
}

preflight() {
  log "Preflight check"
  log "repo: $ROOT"
  log "source: $SRC_HOME"
  log

  if [[ ! -d "$SRC_HOME" ]]; then
    log "ERROR: missing source directory: $SRC_HOME"
    return 1
  fi

  local missing=0
  local f
  for f in \
    .config/environment.d/90-fcitx5.conf \
    .config/gtk-3.0/settings.ini \
    .config/gtk-4.0/settings.ini \
    .config/fcitx5/config \
    .config/fcitx5/profile \
    .config/fcitx5/conf/clipboard.conf \
    .config/fcitx5/conf/notifications.conf \
    .config/fcitx5/conf/xcb.conf \
    .config/fcitx5/conf/fcitx5-cskk \
    .config/hypr/hey-omarchy.lua \
    .config/hypr/hey-omarchy-bindings.lua \
    .config/hypr/keymap-kana-altgr.xkb \
    .config/systemd/user/lid-nosuspend.service \
    .config/systemd/user/hypr-auto-rotate.service \
    .config/omarchy/hey-omarchy.json \
    .config/omarchy/plugins/hey-omarchy/manifest.json \
    .config/omarchy/plugins/hey-omarchy-lock/manifest.json \
    .local/bin/hey-hypr-common \
    .local/bin/hypr-auto-rotate \
    .local/bin/hypr-ws \
    .local/bin/hyprsunset-adjust \
    .local/bin/hypr-opacity-adjust \
    .local/bin/hypr-blur-adjust \
    .local/bin/hypr-gaps-adjust \
    .local/bin/hypr-scale-adjust \
    .local/bin/hypr-refresh-toggle \
    .local/bin/hypr-main-monitor-toggle \
    .local/bin/hypr-internal-display-toggle \
    .local/bin/hypr-lid-suspend-toggle \
    .local/bin/hypr-keyboard-clean-toggle \
    .local/bin/hypr-cursor-invisible-toggle \
    .local/bin/fcitx-en-toggle \
    .local/bin/ddc-brightness \
    .local/bin/bt-roba \
    .local/bin/bluez-agent-auto \
    .local/bin/bluez-discovery-keepalive \
    .local/bin/waybar-main-monitor \
    .local/bin/waybar-ddc-brightness \
    .local/bin/waybar-lid-suspend \
    .local/bin/waybar-fcitx-en \
    .local/bin/waybar-keyboard-clean \
    .local/bin/waybar-cursor-invisible \
    .local/bin/waybar-bt-roba \
    .local/bin/waybar-bt-roba-toggle \
    .local/bin/waybar-wwan \
    .local/bin/wwan-menu \
    .local/bin/wwan-latency-switcher \
    .local/bin/waybar-tailscale \
    .local/bin/waybar-tailscale-toggle \
    .local/bin/waybar-tailscale-peers
  do
    if [[ -f "$SRC_HOME/$f" ]]; then
      log "ok: $f"
    else
      log "MISSING: $f"
      missing=1
    fi
  done

  log

  local c
  for c in install cp mkdir cmp date; do
    if command -v "$c" >/dev/null 2>&1; then
      log "cmd: $c"
    else
      log "cmd: $c (missing)"
    fi
  done

  for c in python python3 jq hyprctl systemctl notify-send omarchy nmcli mmcli yay; do
    if command -v "$c" >/dev/null 2>&1; then
      log "cmd: $c"
    else
      log "cmd: $c (missing)"
    fi
  done

  log
  if detect_nvidia; then
    log "detect: nvidia=yes"
  else
    log "detect: nvidia=no"
  fi
  if hyprctl_has_monitor "DP-4"; then
    log "detect: monitor DP-4=yes"
  else
    log "detect: monitor DP-4=no/unknown"
  fi

  if (( missing )); then
    log
    log "ERROR: repo is missing required source files"
    return 1
  fi

  return 0
}

ts() {
  date +%Y%m%d-%H%M%S
}

run() {
  if (( DRY_RUN )); then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

install_yay_packages() {
  if (( SKIP_PACKAGES )); then
    log "skip: packages (--skip-packages)"
    return 0
  fi

  if ! command -v yay >/dev/null 2>&1; then
    log "note: yay not found; skipping package install"
    return 0
  fi

  # Derived from reoring's current install state.
  local -a pkgs=(
    fcitx5
    fcitx5-configtool
    fcitx5-gtk
    fcitx5-qt
    cskk-git
    cskk-git-debug
    fcitx5-cskk-git
    fcitx5-cskk-git-debug
    skk-jisyo
    ddcutil
  )

  log "Installing packages via yay (may prompt for sudo): ${pkgs[*]}"
  run yay -S --needed "${pkgs[@]}" || log "note: yay package install failed; continuing"
}

backup_if_needed() {
  local dest="$1"
  if [[ ! -e "$dest" ]]; then
    return 0
  fi

  local backup="${dest}.bak.$(ts)"
  run mkdir -p "$(dirname "$backup")"
  run cp -a "$dest" "$backup"
  log "backup: $dest -> $backup"
}

install_file() {
  local src="$1"
  local dest="$2"
  local mode="$3"

  if [[ ! -f "$src" ]]; then
    log "ERROR: missing source file: $src"
    return 1
  fi

  if [[ -e "$dest" ]] && cmp -s "$src" "$dest"; then
    log "ok: $dest"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    backup_if_needed "$dest"
  fi

  run mkdir -p "$(dirname "$dest")"
  run install -m "$mode" "$src" "$dest"
  log "installed: $dest"
}

detect_nvidia() {
  command -v nvidia-smi >/dev/null 2>&1 && return 0
  [[ -d /proc/driver/nvidia ]] && return 0
  return 1
}

hyprctl_has_monitor() {
  local name="$1"
  command -v hyprctl >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  hyprctl monitors -j 2>/dev/null | jq -e --arg n "$name" 'any(.[]; .name == $n)' >/dev/null 2>&1
}

configure_hyprland() {
  local file="$HOME/.config/hypr/hyprland.lua"
  if [[ ! -f "$file" ]]; then
    install_file "$OMARCHY_ROOT/config/hypr/hyprland.lua" "$file" 0644
  fi

  local nvidia=false
  if (( ! SKIP_NVIDIA_ENV )) && { (( FORCE_NVIDIA_ENV )) || detect_nvidia; }; then
    nvidia=true
  fi

  local tmp
  tmp=$(mktemp)
  printf 'return { force_monitors = %s, nvidia = %s }\n' \
    "$([[ $FORCE_MONITORS == 1 ]] && echo true || echo false)" "$nvidia" >"$tmp"
  install_file "$tmp" "$HOME/.config/hypr/hey-omarchy-options.lua" 0644
  rm -f "$tmp"

  if (( DRY_RUN )) && [[ ! -f "$file" ]]; then
    log "[dry-run] append require(\"hypr.hey-omarchy\") to $file"
    return 0
  fi

  tmp=$(mktemp)
  python3 - "$file" >"$tmp" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
loaded = re.search(r"""^\s*require\s*\(?\s*["']hypr\.hey-omarchy["']\s*\)?\s*;?\s*(?:--.*)?$""", text, re.M)
if not loaded:
    text = text.rstrip() + '\n\n-- Personal Quattro customizations, after Omarchy and user defaults.\nrequire("hypr.hey-omarchy")\n'
sys.stdout.write(text)
PY
  install_file "$tmp" "$file" 0644
  rm -f "$tmp"
}

configure_shell() {
  local tmp
  tmp=$(mktemp)
  if ! python3 "$ROOT/merge-shell-config.py" \
    "$HOME/.config/omarchy/shell.json" "$SRC_HOME/.config/omarchy/hey-omarchy.json" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  install_file "$tmp" "$HOME/.config/omarchy/shell.json" 0644
  rm -f "$tmp"
}

ensure_libcskk_metadata_has_passthrough() {
  local metadata="$1"

  if [[ ! -f "$metadata" ]]; then
    log "note: missing libcskk metadata: $metadata"
    return 0
  fi

  if grep -q '^\[passthrough_ascii\]' "$metadata"; then
    log "ok: libcskk metadata has passthrough_ascii"
    return 0
  fi

  backup_if_needed "$metadata"
  if (( DRY_RUN )); then
    log "[dry-run] append passthrough_ascii to: $metadata"
    return 0
  fi

  python - "$metadata" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")

if "[passthrough_ascii]" in text:
    raise SystemExit(0)

block = """

[passthrough_ascii]
name = "Passthrough ASCII"
description = "default rule with ASCII passthrough"
path = "passthrough_ascii"
"""

if text and not text.endswith("\n"):
    text += "\n"

path.write_text(text + block.lstrip("\n"), encoding="utf-8")
PY

  log "updated: $metadata"
}

generate_libcskk_passthrough_ascii_rule() {
  local src="$1"
  local dest="$2"
  local tmp="${dest}.tmp"

  if [[ ! -f "$src" ]]; then
    log "note: missing libcskk rule source: $src"
    return 0
  fi

  if (( DRY_RUN )); then
    log "[dry-run] generate libcskk passthrough rule: $dest"
    return 0
  fi

  run mkdir -p "$(dirname "$dest")"

  python - "$src" "$tmp" <<'PY'
import sys

src_path = sys.argv[1]
out_path = sys.argv[2]

with open(src_path, "r", encoding="utf-8", errors="replace") as f:
    lines = f.readlines()

def is_section_header(line: str) -> bool:
    s = line.strip()
    return s.startswith("[") and s.endswith("]")

ascii_section = """[direct.ascii]
\"C-g\" = [\"PassthroughKeyEvent\"]
\"C-j\" = [\"ChangeInputMode(Hiragana)\"]

# Common Ctrl shortcuts (pass through to apps).
\"C-a\" = [\"PassthroughKeyEvent\"]
\"C-b\" = [\"PassthroughKeyEvent\"]
\"C-c\" = [\"PassthroughKeyEvent\"]
\"C-d\" = [\"PassthroughKeyEvent\"]
\"C-e\" = [\"PassthroughKeyEvent\"]
\"C-f\" = [\"PassthroughKeyEvent\"]
\"C-h\" = [\"PassthroughKeyEvent\"]
\"C-i\" = [\"PassthroughKeyEvent\"]
\"C-k\" = [\"PassthroughKeyEvent\"]
\"C-l\" = [\"PassthroughKeyEvent\"]
\"C-n\" = [\"PassthroughKeyEvent\"]
\"C-o\" = [\"PassthroughKeyEvent\"]
\"C-p\" = [\"PassthroughKeyEvent\"]
\"C-q\" = [\"PassthroughKeyEvent\"]
\"C-r\" = [\"PassthroughKeyEvent\"]
\"C-s\" = [\"PassthroughKeyEvent\"]
\"C-t\" = [\"PassthroughKeyEvent\"]
\"C-u\" = [\"PassthroughKeyEvent\"]
\"C-v\" = [\"PassthroughKeyEvent\"]
\"C-w\" = [\"PassthroughKeyEvent\"]
\"C-x\" = [\"PassthroughKeyEvent\"]
\"C-y\" = [\"PassthroughKeyEvent\"]
\"C-z\" = [\"PassthroughKeyEvent\"]

\"C-A\" = [\"PassthroughKeyEvent\"]
\"C-B\" = [\"PassthroughKeyEvent\"]
\"C-C\" = [\"PassthroughKeyEvent\"]
\"C-D\" = [\"PassthroughKeyEvent\"]
\"C-E\" = [\"PassthroughKeyEvent\"]
\"C-F\" = [\"PassthroughKeyEvent\"]
\"C-G\" = [\"PassthroughKeyEvent\"]
\"C-H\" = [\"PassthroughKeyEvent\"]
\"C-I\" = [\"PassthroughKeyEvent\"]
\"C-J\" = [\"PassthroughKeyEvent\"]
\"C-K\" = [\"PassthroughKeyEvent\"]
\"C-L\" = [\"PassthroughKeyEvent\"]
\"C-M\" = [\"PassthroughKeyEvent\"]
\"C-N\" = [\"PassthroughKeyEvent\"]
\"C-O\" = [\"PassthroughKeyEvent\"]
\"C-P\" = [\"PassthroughKeyEvent\"]
\"C-Q\" = [\"PassthroughKeyEvent\"]
\"C-R\" = [\"PassthroughKeyEvent\"]
\"C-S\" = [\"PassthroughKeyEvent\"]
\"C-T\" = [\"PassthroughKeyEvent\"]
\"C-U\" = [\"PassthroughKeyEvent\"]
\"C-V\" = [\"PassthroughKeyEvent\"]
\"C-W\" = [\"PassthroughKeyEvent\"]
\"C-X\" = [\"PassthroughKeyEvent\"]
\"C-Y\" = [\"PassthroughKeyEvent\"]
\"C-Z\" = [\"PassthroughKeyEvent\"]

\"C-bracketleft\" = [\"PassthroughKeyEvent\"]
\"C-bracketright\" = [\"PassthroughKeyEvent\"]
\"C-backslash\" = [\"PassthroughKeyEvent\"]
\"C-asciicircum\" = [\"PassthroughKeyEvent\"]
\"C-underscore\" = [\"PassthroughKeyEvent\"]

# Pass most keys through so apps/games receive key events.
\"Escape\" = [\"PassthroughKeyEvent\"]
\"Tab\" = [\"PassthroughKeyEvent\"]
\"Return\" = [\"PassthroughKeyEvent\"]
\"C-m\" = [\"PassthroughKeyEvent\"]
\"space\" = [\"PassthroughKeyEvent\"]
\"BackSpace\" = [\"PassthroughKeyEvent\"]
\"Delete\" = [\"PassthroughKeyEvent\"]
\"Left\" = [\"PassthroughKeyEvent\"]
\"Right\" = [\"PassthroughKeyEvent\"]
\"Up\" = [\"PassthroughKeyEvent\"]
\"Down\" = [\"PassthroughKeyEvent\"]
\"Home\" = [\"PassthroughKeyEvent\"]
\"End\" = [\"PassthroughKeyEvent\"]
\"Page_Up\" = [\"PassthroughKeyEvent\"]
\"Next\" = [\"PassthroughKeyEvent\"]

\"0\" = [\"PassthroughKeyEvent\"]
\"1\" = [\"PassthroughKeyEvent\"]
\"2\" = [\"PassthroughKeyEvent\"]
\"3\" = [\"PassthroughKeyEvent\"]
\"4\" = [\"PassthroughKeyEvent\"]
\"5\" = [\"PassthroughKeyEvent\"]
\"6\" = [\"PassthroughKeyEvent\"]
\"7\" = [\"PassthroughKeyEvent\"]
\"8\" = [\"PassthroughKeyEvent\"]
\"9\" = [\"PassthroughKeyEvent\"]

\"a\" = [\"PassthroughKeyEvent\"]
\"b\" = [\"PassthroughKeyEvent\"]
\"c\" = [\"PassthroughKeyEvent\"]
\"d\" = [\"PassthroughKeyEvent\"]
\"e\" = [\"PassthroughKeyEvent\"]
\"f\" = [\"PassthroughKeyEvent\"]
\"g\" = [\"PassthroughKeyEvent\"]
\"h\" = [\"PassthroughKeyEvent\"]
\"i\" = [\"PassthroughKeyEvent\"]
\"j\" = [\"PassthroughKeyEvent\"]
\"k\" = [\"PassthroughKeyEvent\"]
\"l\" = [\"PassthroughKeyEvent\"]
\"m\" = [\"PassthroughKeyEvent\"]
\"n\" = [\"PassthroughKeyEvent\"]
\"o\" = [\"PassthroughKeyEvent\"]
\"p\" = [\"PassthroughKeyEvent\"]
\"q\" = [\"PassthroughKeyEvent\"]
\"r\" = [\"PassthroughKeyEvent\"]
\"s\" = [\"PassthroughKeyEvent\"]
\"t\" = [\"PassthroughKeyEvent\"]
\"u\" = [\"PassthroughKeyEvent\"]
\"v\" = [\"PassthroughKeyEvent\"]
\"w\" = [\"PassthroughKeyEvent\"]
\"x\" = [\"PassthroughKeyEvent\"]
\"y\" = [\"PassthroughKeyEvent\"]
\"z\" = [\"PassthroughKeyEvent\"]

\"A\" = [\"PassthroughKeyEvent\"]
\"B\" = [\"PassthroughKeyEvent\"]
\"C\" = [\"PassthroughKeyEvent\"]
\"D\" = [\"PassthroughKeyEvent\"]
\"E\" = [\"PassthroughKeyEvent\"]
\"F\" = [\"PassthroughKeyEvent\"]
\"G\" = [\"PassthroughKeyEvent\"]
\"H\" = [\"PassthroughKeyEvent\"]
\"I\" = [\"PassthroughKeyEvent\"]
\"J\" = [\"PassthroughKeyEvent\"]
\"K\" = [\"PassthroughKeyEvent\"]
\"L\" = [\"PassthroughKeyEvent\"]
\"M\" = [\"PassthroughKeyEvent\"]
\"N\" = [\"PassthroughKeyEvent\"]
\"O\" = [\"PassthroughKeyEvent\"]
\"P\" = [\"PassthroughKeyEvent\"]
\"Q\" = [\"PassthroughKeyEvent\"]
\"R\" = [\"PassthroughKeyEvent\"]
\"S\" = [\"PassthroughKeyEvent\"]
\"T\" = [\"PassthroughKeyEvent\"]
\"U\" = [\"PassthroughKeyEvent\"]
\"V\" = [\"PassthroughKeyEvent\"]
\"W\" = [\"PassthroughKeyEvent\"]
\"X\" = [\"PassthroughKeyEvent\"]
\"Y\" = [\"PassthroughKeyEvent\"]
\"Z\" = [\"PassthroughKeyEvent\"]

\"minus\" = [\"PassthroughKeyEvent\"]
\"underscore\" = [\"PassthroughKeyEvent\"]
\"equal\" = [\"PassthroughKeyEvent\"]
\"plus\" = [\"PassthroughKeyEvent\"]
\"bracketleft\" = [\"PassthroughKeyEvent\"]
\"braceleft\" = [\"PassthroughKeyEvent\"]
\"bracketright\" = [\"PassthroughKeyEvent\"]
\"braceright\" = [\"PassthroughKeyEvent\"]
\"backslash\" = [\"PassthroughKeyEvent\"]
\"bar\" = [\"PassthroughKeyEvent\"]
\"semicolon\" = [\"PassthroughKeyEvent\"]
\"colon\" = [\"PassthroughKeyEvent\"]
\"apostrophe\" = [\"PassthroughKeyEvent\"]
\"quotedbl\" = [\"PassthroughKeyEvent\"]
\"comma\" = [\"PassthroughKeyEvent\"]
\"less\" = [\"PassthroughKeyEvent\"]
\"period\" = [\"PassthroughKeyEvent\"]
\"greater\" = [\"PassthroughKeyEvent\"]
\"slash\" = [\"PassthroughKeyEvent\"]
\"question\" = [\"PassthroughKeyEvent\"]
\"grave\" = [\"PassthroughKeyEvent\"]
\"asciitilde\" = [\"PassthroughKeyEvent\"]

\"exclam\" = [\"PassthroughKeyEvent\"]
\"at\" = [\"PassthroughKeyEvent\"]
\"numbersign\" = [\"PassthroughKeyEvent\"]
\"dollar\" = [\"PassthroughKeyEvent\"]
\"percent\" = [\"PassthroughKeyEvent\"]
\"asciicircum\" = [\"PassthroughKeyEvent\"]
\"ampersand\" = [\"PassthroughKeyEvent\"]
\"asterisk\" = [\"PassthroughKeyEvent\"]
\"parenleft\" = [\"PassthroughKeyEvent\"]
\"parenright\" = [\"PassthroughKeyEvent\"]

# Shifted variants. Depending on the backend, some keys may be reported as an
# unshifted keysym with Shift modifier instead of a distinct keysym.
\"(shift 0)\" = [\"PassthroughKeyEvent\"]
\"(shift 1)\" = [\"PassthroughKeyEvent\"]
\"(shift 2)\" = [\"PassthroughKeyEvent\"]
\"(shift 3)\" = [\"PassthroughKeyEvent\"]
\"(shift 4)\" = [\"PassthroughKeyEvent\"]
\"(shift 5)\" = [\"PassthroughKeyEvent\"]
\"(shift 6)\" = [\"PassthroughKeyEvent\"]
\"(shift 7)\" = [\"PassthroughKeyEvent\"]
\"(shift 8)\" = [\"PassthroughKeyEvent\"]
\"(shift 9)\" = [\"PassthroughKeyEvent\"]

\"(shift minus)\" = [\"PassthroughKeyEvent\"]
\"(shift equal)\" = [\"PassthroughKeyEvent\"]
\"(shift bracketleft)\" = [\"PassthroughKeyEvent\"]
\"(shift bracketright)\" = [\"PassthroughKeyEvent\"]
\"(shift backslash)\" = [\"PassthroughKeyEvent\"]
\"(shift semicolon)\" = [\"PassthroughKeyEvent\"]
\"(shift apostrophe)\" = [\"PassthroughKeyEvent\"]
\"(shift comma)\" = [\"PassthroughKeyEvent\"]
\"(shift period)\" = [\"PassthroughKeyEvent\"]
\"(shift slash)\" = [\"PassthroughKeyEvent\"]
\"(shift grave)\" = [\"PassthroughKeyEvent\"]

# Some backends keep Shift modifier even when keysym is already shifted.
\"(shift underscore)\" = [\"PassthroughKeyEvent\"]
\"(shift plus)\" = [\"PassthroughKeyEvent\"]
\"(shift braceleft)\" = [\"PassthroughKeyEvent\"]
\"(shift braceright)\" = [\"PassthroughKeyEvent\"]
\"(shift bar)\" = [\"PassthroughKeyEvent\"]
\"(shift colon)\" = [\"PassthroughKeyEvent\"]
\"(shift quotedbl)\" = [\"PassthroughKeyEvent\"]
\"(shift less)\" = [\"PassthroughKeyEvent\"]
\"(shift greater)\" = [\"PassthroughKeyEvent\"]
\"(shift question)\" = [\"PassthroughKeyEvent\"]
\"(shift asciitilde)\" = [\"PassthroughKeyEvent\"]

\"(shift exclam)\" = [\"PassthroughKeyEvent\"]
\"(shift at)\" = [\"PassthroughKeyEvent\"]
\"(shift numbersign)\" = [\"PassthroughKeyEvent\"]
\"(shift dollar)\" = [\"PassthroughKeyEvent\"]
\"(shift percent)\" = [\"PassthroughKeyEvent\"]
\"(shift asciicircum)\" = [\"PassthroughKeyEvent\"]
\"(shift ampersand)\" = [\"PassthroughKeyEvent\"]
\"(shift asterisk)\" = [\"PassthroughKeyEvent\"]
\"(shift parenleft)\" = [\"PassthroughKeyEvent\"]
\"(shift parenright)\" = [\"PassthroughKeyEvent\"]
"""

out = []
in_metadata = False
in_ascii = False
ascii_written = False

for line in lines:
    stripped = line.strip()

    if stripped == "[direct.ascii]":
        out.append(ascii_section)
        in_ascii = True
        ascii_written = True
        continue

    if in_ascii:
        if is_section_header(line):
            in_ascii = False
        else:
            continue

    if stripped == "[metadata]":
        in_metadata = True
        out.append(line)
        continue

    if in_metadata and is_section_header(line):
        in_metadata = False

    if in_metadata:
        if stripped.startswith("name ="):
            out.append('name = "passthrough_ascii"\n')
            continue
        if stripped.startswith("description ="):
            out.append('description = "default typing rule (ASCII passthrough)"\n')
            continue

    out.append(line)

if not ascii_written:
    raise SystemExit(f"ERROR: missing [direct.ascii] section in: {src_path}")

with open(out_path, "w", encoding="utf-8") as f:
    f.writelines(out)
PY

  install_file "$tmp" "$dest" 0644
  run rm -f "$tmp"
}

setup_cskk_passthrough_ascii() {
  local sys_rules="/usr/share/libcskk/rules"
  local user_rules="$HOME/.local/share/libcskk/rules"
  local sys_default_rule="$sys_rules/default/rule.toml"

  if [[ ! -d "$sys_rules" ]]; then
    log "note: libcskk system rules not found: $sys_rules"
    return 0
  fi

  # libcskk prefers ~/.local/share/libcskk/rules when it exists. Ensure we have
  # a complete baseline (metadata + default rules) so fcitx5-cskk can create a
  # context reliably.
  if [[ ! -f "$user_rules/metadata.toml" ]]; then
    if [[ -f "$sys_rules/metadata.toml" ]]; then
      install_file "$sys_rules/metadata.toml" "$user_rules/metadata.toml" 0644
    else
      log "note: missing libcskk metadata: $sys_rules/metadata.toml"
      return 0
    fi
  fi

  if [[ ! -f "$user_rules/default/rule.toml" ]]; then
    if [[ -f "$sys_default_rule" ]]; then
      install_file "$sys_default_rule" "$user_rules/default/rule.toml" 0644
    else
      log "note: missing libcskk default rule: $sys_default_rule"
      return 0
    fi
  fi

  if grep -q '^\[azik\]' "$user_rules/metadata.toml" 2>/dev/null; then
    if [[ -f "$sys_rules/azik/rule.toml" && ! -f "$user_rules/azik/rule.toml" ]]; then
      install_file "$sys_rules/azik/rule.toml" "$user_rules/azik/rule.toml" 0644
    fi
  fi

  ensure_libcskk_metadata_has_passthrough "$user_rules/metadata.toml"
  generate_libcskk_passthrough_ascii_rule "$sys_default_rule" "$user_rules/passthrough_ascii/rule.toml"
}

# cskk-git (AUR) installs libcskk under /usr/lib/cskk/, which is not on the
# default dynamic linker search path. Without this, fcitx5-cskk.so fails to
# dlopen libcskk.so.3 and CSKK silently disappears from fcitx5's addon list.
# Register the directory system-wide so the fix is independent of how fcitx5
# is launched (systemd user service, Hyprland exec-once, manual, etc.).
ensure_libcskk_ldconfig() {
  local conf="/etc/ld.so.conf.d/cskk.conf"
  local line="/usr/lib/cskk"

  if [[ ! -e /usr/lib/cskk/libcskk.so.3 ]]; then
    log "skip: libcskk not under /usr/lib/cskk; ld.so.conf.d fix not needed"
    return 0
  fi

  if [[ -f "$conf" ]] && grep -Fxq "$line" "$conf"; then
    log "ok: $conf"
    return 0
  fi

  if [[ $EUID -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    log "note: sudo not available; cannot write $conf (CSKK may fail to load)"
    return 0
  fi

  log "Writing $conf (may prompt for sudo) so fcitx5-cskk can find libcskk.so.3"
  if (( DRY_RUN )); then
    log "[dry-run] echo '$line' | sudo tee $conf"
    log "[dry-run] sudo ldconfig"
    return 0
  fi

  if [[ $EUID -eq 0 ]]; then
    if ! printf '%s\n' "$line" > "$conf"; then
      log "ERROR: failed to write $conf"
      return 1
    fi
    ldconfig || log "note: ldconfig failed"
  else
    if ! printf '%s\n' "$line" | sudo tee "$conf" >/dev/null; then
      log "ERROR: failed to write $conf via sudo"
      return 1
    fi
    sudo ldconfig || log "note: sudo ldconfig failed"
  fi
  log "installed: $conf"
}

if (( CHECK_ONLY )); then
  preflight
  exit $?
fi

log "Applying reoring customizations to: $HOME"
preflight
if [[ ! -f "$OMARCHY_ROOT/default/hypr/bootstrap.lua" ]]; then
  log "ERROR: this bundle requires Omarchy Quattro with native Lua configuration."
  exit 1
fi

install_yay_packages

# Fcitx5 is aggressive about autosaving its config on shutdown. If we update
# ~/.config/fcitx5/* while the daemon is running and then restart it, the
# shutdown autosave can overwrite our changes. To avoid that, stop fcitx5 first
# (only if it was running), then start it again after we install the files.
FCITX_SERVICE="omarchy-fcitx5.service"
FCITX_WAS_ACTIVE=0
restart_fcitx() {
  if (( FCITX_WAS_ACTIVE )); then
    run systemctl --user start "$FCITX_SERVICE"
    FCITX_WAS_ACTIVE=0
  fi
}
trap restart_fcitx EXIT
if command -v systemctl >/dev/null 2>&1; then
  if systemctl --user is-active --quiet "$FCITX_SERVICE"; then
    FCITX_WAS_ACTIVE=1
    run systemctl --user stop "$FCITX_SERVICE"
  fi
fi

# Fcitx5 (IME)
install_file "$SRC_HOME/.config/environment.d/90-fcitx5.conf" "$HOME/.config/environment.d/90-fcitx5.conf" 0644

# GTK (key theme / window controls)
install_file "$SRC_HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini" 0644
install_file "$SRC_HOME/.config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini" 0644

install_file "$SRC_HOME/.config/fcitx5/config" "$HOME/.config/fcitx5/config" 0644
install_file "$SRC_HOME/.config/fcitx5/profile" "$HOME/.config/fcitx5/profile" 0644
install_file "$SRC_HOME/.config/fcitx5/conf/notifications.conf" "$HOME/.config/fcitx5/conf/notifications.conf" 0644
install_file "$SRC_HOME/.config/fcitx5/conf/xcb.conf" "$HOME/.config/fcitx5/conf/xcb.conf" 0644
install_file "$SRC_HOME/.config/fcitx5/conf/clipboard.conf" "$HOME/.config/fcitx5/conf/clipboard.conf" 0644
install_file "$SRC_HOME/.config/fcitx5/conf/fcitx5-cskk" "$HOME/.config/fcitx5/conf/fcitx5-cskk" 0644

setup_cskk_passthrough_ascii

apply_gtk_gsettings() {
  if ! command -v gsettings >/dev/null 2>&1; then
    log "note: gsettings not found; skipping GTK gsettings"
    return 0
  fi

  # Best-effort: in many GTK setups, XSettings/GSettings override ~/.config/gtk-*/settings.ini.
  # These keys are commonly consumed by GTK apps (especially on GNOME/libadwaita stacks).
  run gsettings set org.gnome.desktop.interface gtk-key-theme 'Emacs' \
    || log "note: failed to set org.gnome.desktop.interface gtk-key-theme"
  run gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' \
    || log "note: failed to set org.gnome.desktop.wm.preferences button-layout"
}

if (( APPLY_GTK_GSETTINGS )); then
  apply_gtk_gsettings
else
  log "note: skipping GTK gsettings (--no-gtk-gsettings)"
fi

# Install dedicated Quattro modules without replacing the user's standard modules.
for src in "$SRC_HOME"/.config/hypr/*.lua "$SRC_HOME"/.config/hypr/*.xkb; do
  [[ -f "$src" ]] || continue
  install_file "$src" "$HOME/.config/hypr/$(basename "$src")" 0644
done

# JSON status producers retain their command names but are consumed by Quickshell.
for src in "$SRC_HOME"/.local/bin/*; do
  [[ -f "$src" ]] || continue
  install_file "$src" "$HOME/.local/bin/$(basename "$src")" 0755
done

configure_hyprland

# Preserve the enabled/disabled state of the user's optional services.
for src in "$SRC_HOME"/.config/systemd/user/*.service; do
  install_file "$src" "$HOME/.config/systemd/user/$(basename "$src")" 0644
done
run systemctl --user daemon-reload

# Fcitx5: cskk addon depends on libcskk (cskk-git installs it under /usr/lib/cskk).
# Make libcskk.so.3 discoverable via ld.so.conf.d so fcitx5-cskk loads regardless
# of how fcitx5 is launched.
ensure_libcskk_ldconfig

restart_fcitx

# Quattro shell custom widgets and idle behavior.
if (( NO_BAR )); then
  log "skip: shell widgets and idle settings (--no-bar)"
else
  while IFS= read -r -d '' src; do
    rel="${src#"$SRC_HOME/"}"
    install_file "$src" "$HOME/$rel" 0644
  done < <(find "$SRC_HOME/.config/omarchy/plugins" -type f -print0)
  configure_shell
fi

# Optional shaders directory
if (( WITH_SHADERS )); then
  if [[ -d /usr/share/aether/shaders ]]; then
    run mkdir -p "$HOME/.config/hypr/shaders"
    for f in /usr/share/aether/shaders/*.glsl; do
      [[ -e "$f" ]] || continue
      run ln -sf "$f" "$HOME/.config/hypr/shaders/$(basename "$f")"
    done
    log "linked: ~/.config/hypr/shaders -> /usr/share/aether/shaders"
  else
    log "skip: /usr/share/aether/shaders not found"
  fi
fi

# Report configuration errors rather than leaving an apparently successful install.
if command -v hyprctl >/dev/null 2>&1; then
  run hyprctl reload
  if (( ! DRY_RUN )); then
    config_errors=$(hyprctl configerrors)
    if [[ -n "$config_errors" && "$config_errors" != "ok" ]]; then
      log "$config_errors"
      exit 1
    fi
  fi
fi
if (( ! NO_BAR )); then
  # A fresh shell is required to replace cached plugin components reliably.
  run omarchy restart shell
fi

log "Done. Backups are saved as *.bak.YYYYmmdd-HHMMSS next to the originals."
