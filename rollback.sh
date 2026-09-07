#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: rollback.sh [options]

Restore the latest *.bak.YYYYmmdd-HHMMSS backups created by apply.sh.

Options:
  --dry-run   Print actions without changing files
  -h, --help  Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf '%s\n' "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

log() {
  printf '%s\n' "$*" >&2
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

latest_apply_backup_for() {
  local dest="$1"

  shopt -s nullglob
  local candidates=("${dest}.bak."*)
  shopt -u nullglob

  local best_path=""
  local best_ts=""

  local p
  for p in "${candidates[@]}"; do
    [[ "$p" == *".bak.rollback."* ]] && continue

    local t
    t="${p##*.bak.}"
    if [[ "$t" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
      if [[ -z "$best_ts" || "$t" > "$best_ts" ]]; then
        best_ts="$t"
        best_path="$p"
      fi
    fi
  done

  printf '%s' "$best_path"
}

backup_current() {
  local dest="$1"
  if [[ ! -e "$dest" ]]; then
    return 0
  fi

  local backup="${dest}.bak.rollback.$(ts)"
  run mkdir -p "$(dirname "$backup")"
  run cp -a "$dest" "$backup"
  log "backup: $dest -> $backup"
}

restore_one() {
  local dest="$1"

  local backup
  backup="$(latest_apply_backup_for "$dest")"
  if [[ -z "$backup" ]]; then
    log "skip: $dest (no backup found)"
    return 0
  fi

  backup_current "$dest"
  run mkdir -p "$(dirname "$dest")"
  run cp -a "$backup" "$dest"
  log "restored: $dest <- $backup"
}

log "Rolling back reoring customizations in: $HOME"

dests=(
  "$HOME/.config/hypr/hyprland.lua"
  "$HOME/.config/hypr/hey-omarchy-options.lua"
  "$HOME/.config/omarchy/shell.json"
  "$HOME/.local/share/libcskk/rules/metadata.toml"
  "$HOME/.local/share/libcskk/rules/default/rule.toml"
  "$HOME/.local/share/libcskk/rules/azik/rule.toml"
  "$HOME/.local/share/libcskk/rules/passthrough_ascii/rule.toml"
)
while IFS= read -r -d '' src; do
  rel="${src#"$ROOT/home/"}"
  [[ "$rel" == ".config/omarchy/hey-omarchy.json" ]] && continue
  dests+=("$HOME/$rel")
done < <(find "$ROOT/home" -type f -print0)

for dest in "${dests[@]}"; do
  restore_one "$dest"
done

run systemctl --user daemon-reload
run hyprctl reload
if (( ! DRY_RUN )); then
  config_errors=$(hyprctl configerrors)
  if [[ -n "$config_errors" && "$config_errors" != "ok" ]]; then
    log "$config_errors"
    exit 1
  fi
fi
run omarchy restart shell

log "Done."
