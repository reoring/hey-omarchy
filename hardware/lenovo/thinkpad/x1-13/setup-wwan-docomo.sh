#!/usr/bin/env bash
set -euo pipefail

# Setup WWAN (Docomo SIM) on ThinkPad X1 13" with Quectel RM5xx (MHI).
#
# This machine commonly runs Wi-Fi/Ethernet with systemd-networkd + iwd.
# WWAN is easiest to manage via ModemManager + NetworkManager.
#
# Running NetworkManager alongside systemd-networkd is NOT recommended unless you
# ensure they don't manage the same interfaces. This script configures:
# - NetworkManager: manage only WWAN devices
# - systemd-networkd: ignore WWAN devices

MARKER="Managed by hey-omarchy (ThinkPad X1-13 WWAN)"

NM_WWAN_ONLY_CONF="/etc/NetworkManager/conf.d/10-wwan-only.conf"
NETWORKD_UNMANAGED_WWAN="/etc/systemd/network/10-wwan-unmanaged.network"

DEFAULT_APN="spmode.ne.jp"
DEFAULT_CON_NAME="docomo"

DEFAULT_MBIM_TIMEOUT_SECS=12
DEFAULT_WAIT_SECS=30

usage() {
  cat <<'EOF'
Usage:
  setup-wwan-docomo.sh install [--no-upgrade] [--apn APN] [--con-name NAME]
                              [--username USER] [--password PASS]
                              [--no-autoconnect] [--no-connect] [--no-connection]
  setup-wwan-docomo.sh enable [--con-name NAME] [--no-connect]
                             [--wait N] [--mbim-timeout N] [--direct-mbim]
  setup-wwan-docomo.sh uninstall [--con-name NAME] [--keep-services] [--keep-connection]

What it does (install):
  - Installs packages:
      linux-firmware-qcom networkmanager modemmanager libmbim libqmi
      mobile-broadband-provider-info
  - Configures NetworkManager to manage only WWAN interfaces
  - Configures systemd-networkd to ignore WWAN interfaces
  - Enables and starts: ModemManager.service, NetworkManager.service
  - Creates a NetworkManager "gsm" connection (default name: docomo)
  - Optionally brings the connection up once

Options:
  --apn APN          APN to use (default: spmode.ne.jp)
  --con-name NAME    Connection name (default: docomo)
  --username USER    Optional APN username
  --password PASS    Optional APN password (stored by NetworkManager)
  --autoconnect      Enable autoconnect (default; useful to re-enable after --no-autoconnect)
  --no-autoconnect   Disable autoconnect
  --no-connect       Do not run nmcli connection up (may still autoconnect)
  --no-connection    Do not create/modify an NM connection profile
  --mbim-timeout N   Timeout seconds for mbimcli calls (default: 12)
  --wait N           Seconds to wait for modem/device to appear (default: 30)
  --direct-mbim      Force MBIM radio enable via direct device access (stops ModemManager temporarily)
  --no-upgrade       Do not run full system upgrade; use pacman -S --needed

Uninstall options:
  --keep-services    Do not disable NetworkManager/ModemManager
  --keep-connection  Do not delete the NetworkManager connection profile

Notes:
  - If the modem is not detected after install, reboot once (firmware load).
  - If the SIM requires a PIN, unlock via nmcli (example):
      nmcli connection modify docomo gsm.pin 1234
  - If ModemManager logs "software radio switch is OFF", run:
      bash setup-wwan-docomo.sh enable
EOF
}

action="${1:-install}"
shift || true

no_upgrade=0
apn="$DEFAULT_APN"
con_name="$DEFAULT_CON_NAME"
gsm_user=""
gsm_pass=""
autoconnect=1
no_connect=0
no_connection=0
mbim_timeout_secs=$DEFAULT_MBIM_TIMEOUT_SECS
wait_secs=$DEFAULT_WAIT_SECS
direct_mbim=0

keep_services=0
keep_connection=0

while [[ ${#} -gt 0 ]]; do
  case "${1}" in
    --no-upgrade) no_upgrade=1; shift ;;
    --apn) apn="${2:-}"; shift 2 ;;
    --con-name) con_name="${2:-}"; shift 2 ;;
    --username) gsm_user="${2:-}"; shift 2 ;;
    --password) gsm_pass="${2:-}"; shift 2 ;;
    --autoconnect) autoconnect=1; shift ;;
    --no-autoconnect) autoconnect=0; shift ;;
    --no-connect) no_connect=1; shift ;;
    --no-connection) no_connection=1; shift ;;
    --mbim-timeout) mbim_timeout_secs="${2:-}"; shift 2 ;;
    --wait) wait_secs="${2:-}"; shift 2 ;;
    --direct-mbim) direct_mbim=1; shift ;;
    --keep-services) keep_services=1; shift ;;
    --keep-connection) keep_connection=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    *) echo "Unknown arg: ${1}" >&2; usage; exit 2 ;;
  esac
done

case "$action" in
  install|enable|uninstall) ;;
  -h|--help|help) usage; exit 0 ;;
  *) echo "Unknown action: $action" >&2; usage; exit 2 ;;
esac

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

has_marker() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -qF "$MARKER" "$f" 2>/dev/null
}

backup_if_needed() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if has_marker "$f"; then
    return 0
  fi
  local bak="${f}.bak.$(timestamp)"
  $SUDO cp -a "$f" "$bak"
  echo "Backup: $bak"
}

install_file() {
  local mode="$1"
  local path="$2"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  $SUDO install -m "$mode" "$tmp" "$path"
  rm -f "$tmp"
}

run_with_timeout() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "${secs}s" "$@"
  else
    "$@"
  fi
}

detect_mbim_device() {
  local candidates=()
  shopt -s nullglob
  candidates+=(/dev/wwan*mbim*)
  candidates+=(/dev/cdc-wdm*)
  shopt -u nullglob

  local d
  for d in "${candidates[@]}"; do
    if [[ -e "$d" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done

  return 1
}

mbim_query_radio_state() {
  # Prints: "hw=<on/off/?> sw=<on/off/?>" to stdout.
  # Returns 0 if it could query and parsed, non-zero otherwise.
  local dev="$1"
  local mode="${2:-proxy}" # proxy|direct
  shift 2 || true

  local args=()
  args+=(mbimcli -d "$dev")
  if [[ "$mode" == "proxy" ]]; then
    args+=(-p)
  fi
  # Allow passing extra mbimcli open flags, e.g. --device-open-ms-mbimex-v3.
  if [[ ${#} -gt 0 ]]; then
    args+=("$@")
  fi
  args+=(--query-radio-state)

  local out
  if ! out="$(run_with_timeout "$mbim_timeout_secs" $SUDO "${args[@]}" 2>&1)"; then
    return 1
  fi

  # Example lines:
  #   Hardware radio state: 'on'
  #   Software radio state: 'off'
  local hw sw
  hw="$(printf '%s\n' "$out" | sed -n "s/.*Hardware radio state: '\([^']*\)'.*/\1/p" | head -n 1)"
  sw="$(printf '%s\n' "$out" | sed -n "s/.*Software radio state: '\([^']*\)'.*/\1/p" | head -n 1)"

  [[ -n "$hw" || -n "$sw" ]] || return 2
  printf 'hw=%s sw=%s\n' "${hw:-?}" "${sw:-?}"
  return 0
}

mbim_sw_radio_is_on() {
  local st="${1:-}"
  [[ "$st" == *"sw=on"* ]]
}

wait_for_mbim_device() {
  local end=$((SECONDS + wait_secs))
  while (( SECONDS < end )); do
    local dev
    dev="$(detect_mbim_device 2>/dev/null || true)"
    if [[ -n "$dev" ]]; then
      printf '%s\n' "$dev"
      return 0
    fi
    sleep 1
  done
  return 1
}

mhi_soc_reset() {
  # Best-effort modem reset via MHI sysfs.
  local reset_path=""
  local p
  shopt -s nullglob
  for p in /sys/bus/mhi/devices/mhi*/soc_reset; do
    reset_path="$p"
    break
  done
  shopt -u nullglob

  [[ -n "$reset_path" ]] || return 1

  echo "Resetting modem (MHI SoC reset): $reset_path"
  # Use sh -c to ensure redirection runs as root.
  $SUDO sh -c "echo 1 > \"$reset_path\"" 2>/dev/null || return 1
  sleep 3
  return 0
}

mbim_quectel_set_radio_on() {
  local dev="$1"
  shift
  run_with_timeout "$mbim_timeout_secs" $SUDO mbimcli -d "$dev" "$@" --quectel-set-radio-state=on
}

mbim_quectel_send_at() {
  local dev="$1"
  local at_cmd="$2"
  shift 2 || true

  # Try a few accepted syntaxes for mbimcli's quectel command option.
  local forms=()
  forms+=("--quectel-set-command=${at_cmd}")
  forms+=("--quectel-set-command=at,${at_cmd}")
  forms+=("--quectel-set-command=at,\"${at_cmd}\"")

  local f
  for f in "${forms[@]}"; do
    if run_with_timeout "$mbim_timeout_secs" $SUDO mbimcli -d "$dev" "$@" "$f"; then
      return 0
    fi
  done

  return 1
}

mbim_direct_enable_radio() {
  # Tries to set software radio ON via direct access. Expects ModemManager stopped.
  local dev="$1"

  local st=""
  if st="$(mbim_query_radio_state "$dev" direct 2>/dev/null)"; then
    echo "MBIM radio state (direct): $st"
    if mbim_sw_radio_is_on "$st"; then
      return 0
    fi
  fi

  local attempt
  for attempt in default mbimex-v3 mbimex-v2; do
    local extra=()
    case "$attempt" in
      default) ;;
      mbimex-v3) extra=(--device-open-ms-mbimex-v3) ;;
      mbimex-v2) extra=(--device-open-ms-mbimex-v2) ;;
    esac

    if run_with_timeout "$mbim_timeout_secs" $SUDO mbimcli -d "$dev" "${extra[@]}" --set-radio-state=on >/dev/null 2>&1; then
      st="$(mbim_query_radio_state "$dev" direct "${extra[@]}" 2>/dev/null || true)"
      if [[ -n "$st" ]]; then
        echo "MBIM radio state (direct ${attempt}): $st"
      fi
      if mbim_sw_radio_is_on "$st"; then
        return 0
      fi
    fi

    # Toggle OFF -> ON (some firmwares need a transition).
    run_with_timeout "$mbim_timeout_secs" $SUDO mbimcli -d "$dev" "${extra[@]}" --set-radio-state=off >/dev/null 2>&1 || true
    sleep 1
    if run_with_timeout "$mbim_timeout_secs" $SUDO mbimcli -d "$dev" "${extra[@]}" --set-radio-state=on >/dev/null 2>&1; then
      st="$(mbim_query_radio_state "$dev" direct "${extra[@]}" 2>/dev/null || true)"
      if [[ -n "$st" ]]; then
        echo "MBIM radio state (direct ${attempt} toggled): $st"
      fi
      if mbim_sw_radio_is_on "$st"; then
        return 0
      fi
    fi
  done

  # If the standard Basic Connect radio control doesn't work, try Quectel-specific
  # MBIM service commands.
  echo "Basic Connect radio enable did not turn software radio on; trying Quectel MBIM service..."
  for attempt in default mbimex-v3 mbimex-v2; do
    local extra=()
    case "$attempt" in
      default) ;;
      mbimex-v3) extra=(--device-open-ms-mbimex-v3) ;;
      mbimex-v2) extra=(--device-open-ms-mbimex-v2) ;;
    esac

    if mbim_quectel_set_radio_on "$dev" "${extra[@]}" >/dev/null 2>&1; then
      st="$(mbim_query_radio_state "$dev" direct "${extra[@]}" 2>/dev/null || true)"
      if [[ -n "$st" ]]; then
        echo "MBIM radio state (direct ${attempt} after quectel radio): $st"
      fi
      if mbim_sw_radio_is_on "$st"; then
        return 0
      fi
    fi
  done

  echo "Quectel radio enable did not turn software radio on; trying AT+CFUN=1 via Quectel service..."
  for attempt in default mbimex-v3 mbimex-v2; do
    local extra=()
    case "$attempt" in
      default) ;;
      mbimex-v3) extra=(--device-open-ms-mbimex-v3) ;;
      mbimex-v2) extra=(--device-open-ms-mbimex-v2) ;;
    esac

    if mbim_quectel_send_at "$dev" "AT+CFUN=1" "${extra[@]}" >/dev/null 2>&1; then
      sleep 2
      st="$(mbim_query_radio_state "$dev" direct "${extra[@]}" 2>/dev/null || true)"
      if [[ -n "$st" ]]; then
        echo "MBIM radio state (direct ${attempt} after AT+CFUN=1): $st"
      fi
      if mbim_sw_radio_is_on "$st"; then
        return 0
      fi
    fi
  done

  return 1
}

ensure_wwan_radio_on() {
  # Best-effort: unblock rfkill, enable NM WWAN, then force modem radio ON via MBIM.
  if command -v rfkill >/dev/null 2>&1; then
    $SUDO rfkill unblock wwan 2>/dev/null || true
  fi
  if command -v nmcli >/dev/null 2>&1; then
    $SUDO nmcli radio wwan on 2>/dev/null || true
  fi

  if ! command -v mbimcli >/dev/null 2>&1; then
    echo "mbimcli not found; skipping MBIM radio enable"
    return 0
  fi

  local dev
  if ! dev="$(detect_mbim_device 2>/dev/null)"; then
    echo "No MBIM device node found (/dev/wwan*mbim* or /dev/cdc-wdm*); skipping MBIM radio enable"
    return 0
  fi

  echo "Ensuring modem radio is ON (MBIM): $dev"

  local st=""
  local ok=0

  if [[ $direct_mbim -eq 1 ]]; then
    echo "Using direct MBIM access (--direct-mbim)"
    # Fall through to direct path below.
  else
    # Prefer mbim-proxy (when ModemManager is running).
    if run_with_timeout "$mbim_timeout_secs" $SUDO mbimcli -d "$dev" -p --set-radio-state=on >/dev/null 2>&1; then
      echo "MBIM radio: ON (via proxy)"
      if st="$(mbim_query_radio_state "$dev" proxy 2>/dev/null)"; then
        echo "MBIM radio state (proxy): $st"
        if mbim_sw_radio_is_on "$st"; then
          return 0
        fi
      fi
    fi
  fi

  # Fallback: stop ModemManager temporarily and talk directly to the device.
  local mm_was_active=0
  if $SUDO systemctl is-active --quiet ModemManager.service 2>/dev/null; then
    mm_was_active=1
  fi

  echo "Using direct MBIM access (temporary ModemManager stop)"
  $SUDO systemctl stop ModemManager.service 2>/dev/null || true
  sleep 1

  if mbim_direct_enable_radio "$dev"; then
    echo "MBIM software radio: ON"
    ok=1
  else
    echo "Warning: MBIM software radio still OFF; attempting modem reset and retry..." >&2
    if mhi_soc_reset; then
      # After reset, device nodes may disappear and come back.
      dev="$(wait_for_mbim_device 2>/dev/null || true)"
      if [[ -n "$dev" ]] && mbim_direct_enable_radio "$dev"; then
        echo "MBIM software radio: ON (after reset)"
        ok=1
      else
        echo "Error: could not enable MBIM software radio" >&2
      fi
    else
      echo "Error: could not enable MBIM software radio" >&2
    fi
  fi

  if [[ $mm_was_active -eq 1 ]]; then
    $SUDO systemctl start ModemManager.service 2>/dev/null || true
    sleep 1
  fi

  if [[ $ok -eq 1 ]]; then
    return 0
  fi

  echo "Error: MBIM software radio is still OFF; cannot enable modem" >&2
  return 1
}

ensure_services_running() {
  $SUDO systemctl enable --now ModemManager.service 2>/dev/null || $SUDO systemctl start ModemManager.service
  $SUDO systemctl enable --now NetworkManager.service 2>/dev/null || $SUDO systemctl start NetworkManager.service

  # Make sure the new NetworkManager config is picked up.
  $SUDO systemctl reload NetworkManager.service 2>/dev/null || $SUDO systemctl restart NetworkManager.service
}

first_mm_modem_id() {
  command -v mmcli >/dev/null 2>&1 || return 1
  $SUDO mmcli -L 2>/dev/null | sed -n 's|.*/Modem/\([0-9]\+\).*|\1|p' | head -n 1
}

wait_for_mm_modem() {
  command -v mmcli >/dev/null 2>&1 || return 0
  local end=$((SECONDS + wait_secs))
  while (( SECONDS < end )); do
    if $SUDO mmcli -L 2>/dev/null | grep -q '/org/freedesktop/ModemManager1/Modem/'; then
      return 0
    fi
    sleep 1
  done

  echo "Error: ModemManager sees no modems (mmcli -L empty after ${wait_secs}s)" >&2
  return 1
}

nm_wwan_device() {
  command -v nmcli >/dev/null 2>&1 || return 1
  nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2 == "gsm" { print $1; exit }'
}

wait_for_nm_wwan_device() {
  command -v nmcli >/dev/null 2>&1 || return 0
  local end=$((SECONDS + wait_secs))
  while (( SECONDS < end )); do
    local dev
    dev="$(nm_wwan_device 2>/dev/null || true)"
    if [[ -n "$dev" ]]; then
      printf '%s\n' "$dev"
      return 0
    fi
    sleep 1
  done

  echo "Error: NetworkManager has no WWAN device (no gsm device after ${wait_secs}s)" >&2
  return 1
}

best_effort_modem_enable() {
  local mid
  mid="$(first_mm_modem_id || true)"
  [[ -n "$mid" ]] || return 0

  $SUDO mmcli -m "$mid" --set-power-state-on >/dev/null 2>&1 || true
  $SUDO mmcli -m "$mid" -e >/dev/null 2>&1 || true
}

if [[ "$action" == "uninstall" ]]; then
  if [[ $keep_connection -eq 0 ]] && command -v nmcli >/dev/null 2>&1; then
    if $SUDO nmcli connection show "$con_name" >/dev/null 2>&1; then
      $SUDO nmcli connection down "$con_name" >/dev/null 2>&1 || true
      $SUDO nmcli connection delete "$con_name" >/dev/null 2>&1 || true
      echo "Removed connection: $con_name"
    fi
  fi

  if [[ -f "$NM_WWAN_ONLY_CONF" ]] && has_marker "$NM_WWAN_ONLY_CONF"; then
    $SUDO rm -f "$NM_WWAN_ONLY_CONF"
    echo "Removed: $NM_WWAN_ONLY_CONF"
  fi

  if [[ -f "$NETWORKD_UNMANAGED_WWAN" ]] && has_marker "$NETWORKD_UNMANAGED_WWAN"; then
    $SUDO rm -f "$NETWORKD_UNMANAGED_WWAN"
    echo "Removed: $NETWORKD_UNMANAGED_WWAN"
  fi

  if [[ $keep_services -eq 0 ]]; then
    $SUDO systemctl disable --now NetworkManager.service 2>/dev/null || true
    $SUDO systemctl disable --now ModemManager.service 2>/dev/null || true
    echo "Disabled: NetworkManager.service ModemManager.service"
  fi

  echo "Done. Packages were not removed."
  exit 0
fi

if [[ "$action" == "enable" ]]; then
  if ! command -v nmcli >/dev/null 2>&1; then
    echo "nmcli not found; install NetworkManager first (run: $0 install)." >&2
    exit 1
  fi

  ensure_services_running

  # Wait for devices to appear before trying to connect.
  wait_for_mm_modem || exit 1
  wait_for_nm_wwan_device >/dev/null || true

  ensure_wwan_radio_on
  # If the radio enable step had to restart ModemManager, wait again.
  wait_for_mm_modem || true
  wait_for_nm_wwan_device >/dev/null || true
  best_effort_modem_enable

  if [[ $no_connect -eq 0 ]]; then
    echo "Bringing up connection: $con_name"
    if ! $SUDO nmcli -w 60 connection up "$con_name"; then
      echo "Warning: could not bring up connection: $con_name" >&2
      echo "Check with: nmcli device status; mmcli -m 0; journalctl -u ModemManager -b --no-pager | tail -n 80" >&2
      exit 1
    fi
  else
    echo "Skipping connection up (--no-connect)"
  fi

  echo ""
  echo "Status:"
  nmcli device status || true
  if command -v mmcli >/dev/null 2>&1; then
    $SUDO mmcli -L || true
  fi
  exit 0
fi

# install
if ! command -v pacman >/dev/null 2>&1; then
  echo "pacman not found; this script is for Arch Linux." >&2
  exit 1
fi

pkgs=(
  linux-firmware-qcom
  networkmanager
  modemmanager
  libmbim
  libqmi
  mobile-broadband-provider-info
)

if [[ $no_upgrade -eq 1 ]]; then
  $SUDO pacman -S --needed "${pkgs[@]}"
else
  $SUDO pacman -Syu --needed "${pkgs[@]}"
fi

$SUDO install -d -m 0755 /etc/NetworkManager/conf.d
$SUDO install -d -m 0755 /etc/systemd/network

backup_if_needed "$NM_WWAN_ONLY_CONF"
install_file 0644 "$NM_WWAN_ONLY_CONF" <<EOF
# $MARKER
# Only manage WWAN devices; leave Wi-Fi/Ethernet to systemd-networkd/iwd.
[keyfile]
unmanaged-devices=interface-name:lo;interface-name:wl*;interface-name:en*;interface-name:eth*;interface-name:docker*;interface-name:tailscale*;interface-name:br*;interface-name:veth*;interface-name:virbr*;interface-name:tun*;interface-name:tap*
EOF
echo "Installed: $NM_WWAN_ONLY_CONF"

backup_if_needed "$NETWORKD_UNMANAGED_WWAN"
install_file 0644 "$NETWORKD_UNMANAGED_WWAN" <<EOF
# $MARKER
[Match]
Name=ww*

[Link]
Unmanaged=yes
RequiredForOnline=no
EOF
echo "Installed: $NETWORKD_UNMANAGED_WWAN"

ensure_services_running

echo "Enabled: ModemManager.service NetworkManager.service"

if [[ $no_connection -eq 0 ]]; then
  if ! command -v nmcli >/dev/null 2>&1; then
    echo "nmcli not found (NetworkManager not installed correctly?)." >&2
    exit 1
  fi

  if $SUDO nmcli connection show "$con_name" >/dev/null 2>&1; then
    echo "Using existing connection: $con_name"
  else
    $SUDO nmcli connection add type gsm ifname "*" con-name "$con_name" apn "$apn" >/dev/null
    echo "Created connection: $con_name"
  fi

  $SUDO nmcli connection modify "$con_name" gsm.apn "$apn" >/dev/null
  $SUDO nmcli connection modify "$con_name" ipv4.route-metric 700 ipv6.route-metric 700 >/dev/null
  if [[ $autoconnect -eq 1 ]]; then
    # Infinite retries helps auto-reconnect after suspend/resume.
    $SUDO nmcli connection modify "$con_name" connection.autoconnect yes connection.autoconnect-retries 0 >/dev/null
  else
    $SUDO nmcli connection modify "$con_name" connection.autoconnect no >/dev/null
  fi
  if [[ -n "$gsm_user" ]]; then
    $SUDO nmcli connection modify "$con_name" gsm.username "$gsm_user" >/dev/null
  fi
  if [[ -n "$gsm_pass" ]]; then
    $SUDO nmcli connection modify "$con_name" gsm.password "$gsm_pass" >/dev/null
  fi

  echo "Configured connection: $con_name (apn=$apn)"

  if [[ $no_connect -eq 0 ]]; then
    wait_for_mm_modem || exit 1
    wait_for_nm_wwan_device >/dev/null || true
    ensure_wwan_radio_on
    wait_for_mm_modem || true
    wait_for_nm_wwan_device >/dev/null || true
    best_effort_modem_enable
    echo "Bringing up connection (may take a moment)..."
    if ! $SUDO nmcli -w 60 connection up "$con_name"; then
      cat <<'EOF'
Warning: nmcli could not bring the WWAN connection up.

Quick checks:
  mmcli -L
  nmcli device status

If the modem is not listed by mmcli, reboot once after installing linux-firmware-qcom.
If ModemManager says "software radio switch is OFF", run:
  bash setup-wwan-docomo.sh enable
If the SIM needs a PIN, set it then retry:
  nmcli connection modify docomo gsm.pin 1234
  nmcli connection up docomo
EOF
    fi
  fi
else
  echo "Skipping connection profile creation (--no-connection)"
fi

echo ""
echo "Status:"
nmcli device status || true
if command -v mmcli >/dev/null 2>&1; then
  $SUDO mmcli -L || true
fi

cat <<EOF

Done.

Useful commands:
  nmcli connection up "$con_name"
  nmcli connection down "$con_name"
EOF
