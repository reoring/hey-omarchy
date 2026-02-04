#!/usr/bin/env bash
set -euo pipefail

# Install 3D (OpenGL/Vulkan) driver/user-space packages for this machine.
#
# Target: Arch Linux + Intel Lunar Lake (Arc 130V/140V) using the xe kernel driver.
#
# Notes:
# - Mesa provides OpenGL; vulkan-intel provides the Vulkan ICD.
# - Steam/Proton often needs 32-bit (lib32-*) packages, which require multilib.

usage() {
  cat <<'EOF'
Usage:
  setup-3d-packages.sh install [--no-upgrade]

Installs (64-bit):
  - mesa
  - vulkan-intel
  - vulkan-icd-loader
  - mesa-utils (glxinfo)
  - vulkan-tools (vulkaninfo)

Installs (32-bit, if multilib enabled):
  - lib32-mesa
  - lib32-vulkan-intel
  - lib32-vulkan-icd-loader
EOF
}

action="${1:-install}"
shift || true

no_upgrade=0
while [[ ${#} -gt 0 ]]; do
  case "${1}" in
    --no-upgrade) no_upgrade=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    *) echo "Unknown arg: ${1}" >&2; usage; exit 2 ;;
  esac
done

case "$action" in
  install) ;;
  -h|--help|help) usage; exit 0 ;;
  *) echo "Unknown action: $action" >&2; usage; exit 2 ;;
esac

if ! command -v pacman >/dev/null 2>&1; then
  echo "pacman not found; this script is for Arch Linux." >&2
  exit 1
fi

SUDO=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "This script needs root (or sudo) to install packages." >&2
    exit 1
  fi
fi

multilib_enabled() {
  # True when [multilib] is present and has an active Include line.
  # Avoid awk variable name "in" (reserved keyword in some awks).
  [[ -r /etc/pacman.conf ]] || return 1
  awk '
    BEGIN { in_section=0; found=0 }
    /^[[:space:]]*\[multilib\][[:space:]]*$/ { in_section=1; next }
    /^[[:space:]]*\[/ { in_section=0 }
    in_section && $0 !~ /^[[:space:]]*#/ && $0 ~ /^[[:space:]]*Include[[:space:]]*=/ { found=1; exit }
    END { exit(found ? 0 : 1) }
  ' /etc/pacman.conf
}

pkgs=(
  mesa
  vulkan-intel
  vulkan-icd-loader
  mesa-utils
  vulkan-tools
)

lib32_pkgs=(
  lib32-mesa
  lib32-vulkan-intel
  lib32-vulkan-icd-loader
)

if multilib_enabled; then
  pkgs+=("${lib32_pkgs[@]}")
  echo "multilib enabled: will install lib32-* packages"
else
  cat <<'EOF'
Note: multilib is not enabled in /etc/pacman.conf.
Skipping lib32-* packages (Steam/Proton commonly needs them).

To enable multilib, uncomment these lines in /etc/pacman.conf:
  [multilib]
  Include = /etc/pacman.d/mirrorlist

Then run: pacman -Syu
EOF
fi

if [[ $no_upgrade -eq 1 ]]; then
  $SUDO pacman -S --needed "${pkgs[@]}"
else
  $SUDO pacman -Syu --needed "${pkgs[@]}"
fi

echo ""
echo "Installed graphics packages. Quick checks:"
echo "  glxinfo -B"
echo "  vulkaninfo --summary"
