#!/usr/bin/env bash
set -euo pipefail

# Enable fingerprint authentication via fprintd/libfprint on Arch Linux.
#
# What this script does:
# - Installs packages: fprintd, libfprint
# - Enables: fprintd.service
# - Optionally adds pam_fprintd to common PAM entry points (sudo + logins)
# - Optional interactive enrollment for a user

usage() {
  cat <<'EOF'
Usage:
  set-fingerprint.sh install [--no-upgrade] [--no-pam] [--enroll] [--user USER]
  set-fingerprint.sh uninstall [--no-service]

Actions:
  install
    - Installs: fprintd libfprint
    - Enables: fprintd.service
    - Adds to PAM (unless --no-pam):
        /etc/pam.d/sudo
        /etc/pam.d/system-local-login
        /etc/pam.d/login
        /etc/pam.d/greetd
        /etc/pam.d/sddm
        /etc/pam.d/gdm-password
        /etc/pam.d/lightdm

  uninstall
    - Removes only the PAM block added by this script.
    - Disables fprintd.service unless --no-service.

Options:
  --enroll       Run fprintd-enroll interactively for the target user.
  --user USER    User to enroll (defaults to $SUDO_USER or $USER).
  --no-pam       Do not edit /etc/pam.d/*.
  --no-upgrade   Do not run full system upgrade; use pacman -S --needed.
  --no-service   On uninstall: do not disable fprintd.service.
EOF
}

action="${1:-install}"
shift || true

enroll=0
no_pam=0
no_upgrade=0
no_service=0
target_user=""

while [[ ${#} -gt 0 ]]; do
  case "${1}" in
    --enroll) enroll=1; shift ;;
    --user) target_user="${2:-}"; shift 2 ;;
    --no-pam) no_pam=1; shift ;;
    --no-upgrade) no_upgrade=1; shift ;;
    --no-service) no_service=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    *)
      echo "Unknown arg: ${1}" >&2
      usage
      exit 2
      ;;
  esac
done

case "$action" in
  install|uninstall) ;;
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
    echo "This script needs root (or sudo)." >&2
    exit 1
  fi
fi

timestamp() {
  date +%Y%m%d-%H%M%S
}

pam_files=(
  /etc/pam.d/sudo
  /etc/pam.d/system-local-login
  /etc/pam.d/login
  /etc/pam.d/greetd
  /etc/pam.d/sddm
  /etc/pam.d/gdm-password
  /etc/pam.d/lightdm
)

PAM_BEGIN="# BEGIN hey-omarchy fprintd"
PAM_END="# END hey-omarchy fprintd"
PAM_LINE="auth sufficient pam_fprintd.so"

pam_has_our_block() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -qF "$PAM_BEGIN" "$f" 2>/dev/null
}

pam_has_any_fprintd() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -Eq '^[[:space:]]*auth[[:space:]]+[^#]*pam_fprintd\.so' "$f" 2>/dev/null
}

pam_backup() {
  local f="$1"
  local bak="${f}.bak.$(timestamp)"
  $SUDO cp -a "$f" "$bak"
  echo "Backup: $bak"
}

pam_install_block() {
  local f="$1"
  [[ -f "$f" ]] || return 0

  if pam_has_our_block "$f"; then
    echo "PAM already configured (marker found): $f"
    return 0
  fi
  if pam_has_any_fprintd "$f"; then
    echo "PAM already contains pam_fprintd.so (skipping): $f"
    return 0
  fi

  pam_backup "$f"

  local tmp
  tmp="$(mktemp)"
  # Avoid RETURN traps here; keep cleanup explicit.

  awk -v begin="$PAM_BEGIN" -v end="$PAM_END" -v line="$PAM_LINE" '
    BEGIN { inserted=0 }
    /^[[:space:]]*auth[[:space:]]/ && inserted==0 {
      print begin
      print line
      print end
      inserted=1
    }
    { print }
    END {
      if (inserted==0) {
        print ""
        print begin
        print line
        print end
      }
    }
  ' "$f" >"$tmp"

  $SUDO install -m 0644 "$tmp" "$f"
  rm -f "$tmp"
  echo "Updated PAM: $f"
}

pam_remove_block() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if ! pam_has_our_block "$f"; then
    return 0
  fi

  pam_backup "$f"

  local tmp
  tmp="$(mktemp)"
  # Avoid RETURN traps here; keep cleanup explicit.

  awk -v begin="$PAM_BEGIN" -v end="$PAM_END" '
    BEGIN { skipping=0 }
    index($0, begin) { skipping=1; next }
    index($0, end) { skipping=0; next }
    skipping==0 { print }
  ' "$f" >"$tmp"

  $SUDO install -m 0644 "$tmp" "$f"
  rm -f "$tmp"
  echo "Removed PAM block: $f"
}

default_user() {
  if [[ -n "$target_user" ]]; then
    printf '%s\n' "$target_user"
    return 0
  fi
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
    printf '%s\n' "$SUDO_USER"
    return 0
  fi
  printf '%s\n' "${USER:-}"
}

if [[ "$action" == "uninstall" ]]; then
  for f in "${pam_files[@]}"; do
    pam_remove_block "$f"
  done

  if [[ $no_service -eq 0 ]]; then
    $SUDO systemctl disable --now fprintd.service 2>/dev/null || true
    echo "Disabled: fprintd.service"
  fi

  echo "Done. Packages were not removed."
  exit 0
fi

# install
pkgs=(fprintd libfprint)
if [[ $no_upgrade -eq 1 ]]; then
  $SUDO pacman -S --needed "${pkgs[@]}"
else
  $SUDO pacman -Syu --needed "${pkgs[@]}"
fi

$SUDO systemctl enable --now fprintd.service

echo "Enabled: fprintd.service"

if [[ $no_pam -eq 0 ]]; then
  for f in "${pam_files[@]}"; do
    pam_install_block "$f"
  done
else
  echo "Skipping PAM edits (--no-pam)"
fi

if [[ $enroll -eq 1 ]]; then
  u="$(default_user)"
  if [[ -z "$u" ]]; then
    echo "Could not determine a user to enroll. Use --user USER." >&2
    exit 1
  fi
  echo "Enrolling fingerprints for user: $u"
  if [[ -n "$SUDO" && "${EUID:-$(id -u)}" -ne 0 ]]; then
    $SUDO -u "$u" fprintd-enroll
  else
    fprintd-enroll "$u"
  fi
  echo "Verify with: fprintd-verify $u"
else
  u="$(default_user)"
  if [[ -n "$u" ]]; then
    echo "Next: enroll with: fprintd-enroll $u"
    echo "Then verify with: fprintd-verify $u"
  else
    echo "Next: enroll with: fprintd-enroll <user>"
  fi
fi

cat <<'EOF'

Notes:
- If enrollment fails with "No devices available", your sensor may not be supported by
  the installed libfprint build. Collect USB ID via: lsusb -nn
EOF
