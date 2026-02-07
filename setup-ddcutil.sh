#!/usr/bin/env bash
set -euo pipefail

INSTALLER=auto
DO_MODPROBE=1
PERSIST_MODULE=0
DO_UDEV=1
DO_DETECT=1

usage() {
  cat >&2 <<'EOF'
Usage: bash ./setup-ddcutil.sh [options]

Options:
  --yay         Install via yay
  --pacman      Install via pacman
  --no-modprobe Skip: sudo modprobe i2c-dev
  --persist-module  Load i2c-dev on boot (writes /etc/modules-load.d/i2c-dev.conf)
  --no-udev     Skip: sudo ddcutil install-udev-rules
  --no-detect   Skip: ddcutil detect check
  -h, --help    Show help
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yay) INSTALLER=yay ;;
    --pacman) INSTALLER=pacman ;;
    --no-modprobe) DO_MODPROBE=0 ;;
    --persist-module) PERSIST_MODULE=1 ;;
    --no-udev) DO_UDEV=0 ;;
    --no-detect) DO_DETECT=0 ;;
    -h|--help) usage; exit 0 ;;
    *)
      log "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
  shift
done

if [[ "$INSTALLER" == "auto" ]]; then
  if command -v yay >/dev/null 2>&1; then
    INSTALLER=yay
  elif command -v pacman >/dev/null 2>&1; then
    INSTALLER=pacman
  else
    fail "Neither yay nor pacman found"
  fi
fi

case "$INSTALLER" in
  yay)
    log "Installing ddcutil via yay (may prompt for sudo)"
    yay -S --needed ddcutil
    ;;
  pacman)
    if ! command -v sudo >/dev/null 2>&1; then
      fail "sudo not found (required for pacman install)"
    fi
    log "Installing ddcutil via pacman"
    sudo pacman -S --needed ddcutil
    ;;
  *)
    fail "Invalid installer: $INSTALLER"
    ;;
esac

command -v ddcutil >/dev/null 2>&1 || fail "ddcutil not found after install"

if (( DO_MODPROBE )); then
  command -v sudo >/dev/null 2>&1 || fail "sudo not found (required for modprobe)"
  if ! compgen -G '/dev/i2c-*' >/dev/null; then
    log
    log "Loading kernel module: i2c-dev"
    sudo modprobe i2c-dev || true
  fi
fi

if (( PERSIST_MODULE )); then
  command -v sudo >/dev/null 2>&1 || fail "sudo not found (required to write /etc)"
  log
  log "Enabling i2c-dev auto-load at boot"
  sudo install -D -m 0644 /dev/stdin /etc/modules-load.d/i2c-dev.conf <<'EOF'
i2c-dev
EOF
fi

if (( DO_UDEV )); then
  command -v sudo >/dev/null 2>&1 || fail "sudo not found (required for udev rules)"
  log
  log "Installing udev rules (recommended; enables non-root access to /dev/i2c-*)"
  sudo ddcutil install-udev-rules
  sudo udevadm control --reload-rules >/dev/null 2>&1 || true
  sudo udevadm trigger --subsystem-match=i2c --action=add >/dev/null 2>&1 || true
  log "Note: you may need to re-login (or reboot) for permissions to apply."
fi

if (( DO_DETECT )); then
  log
  log "Running: ddcutil detect"
  if ddcutil detect; then
    :
  else
    log "ddcutil detect failed; trying: sudo ddcutil detect"
    sudo ddcutil detect || true
  fi
fi

log
log "Next:"
log "  bash ./apply.sh --skip-packages"
log "  ddc-brightness get --display 1"
log
log "(Without apply.sh: bash ./home/.local/bin/ddc-brightness get --display 1)"
