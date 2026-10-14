#!/usr/bin/env bash
set -euo pipefail

# Installs a systemd unit that runs BEFORE sleep.target to work around suspend
# failures caused by Quectel WWAN (mhi-pci-generic) on some ThinkPad systems.
#
# Why a unit (not /etc/systemd/system-sleep):
# - On systemd 259, systemd-suspend.service only runs hooks in
#   /usr/lib/systemd/system-sleep/ (per systemd-sleep(8)).
# - Using a unit is the recommended, configurable interface and lives under /etc.
#
# What it does:
# - On sleep entry: rfkill block wwan, bring WWAN link down, unbind PCI device,
#   unload MHI modules.
# - On resume: reload MHI modules, bind device back, rfkill unblock wwan.
#
# Notes:
# - Requires sudo (writes to /etc and /usr/local)
# - If you do NOT use WWAN at all, blacklisting MHI modules is simpler.

SERVICE_NAME="mhi-wwan-sleep.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
HELPER_DIR="/usr/local/libexec"
HELPER_PATH="${HELPER_DIR}/mhi-wwan-sleep"

# Legacy path from earlier iterations (not used by systemd 259).
LEGACY_HOOK_PATH="/etc/systemd/system-sleep/90-mhi-wwan"

usage() {
  cat <<'EOF'
Usage:
  setup-suspend-mhi-wwan-hook.sh install
  setup-suspend-mhi-wwan-hook.sh uninstall

Installs/removes:
  - /usr/local/libexec/mhi-wwan-sleep
  - /etc/systemd/system/mhi-wwan-sleep.service (WantedBy=sleep.target)
EOF
}

action="${1:-install}"
case "$action" in
  install|uninstall) ;;
  -h|--help|help) usage; exit 0 ;;
  *) echo "Unknown action: $action" >&2; usage; exit 2 ;;
esac

if [[ "$action" == "uninstall" ]]; then
  sudo systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true
  sudo rm -f "$SERVICE_PATH" "$HELPER_PATH" "$LEGACY_HOOK_PATH"
  sudo systemctl daemon-reload
  echo "Removed: $SERVICE_PATH"
  echo "Removed: $HELPER_PATH"
  exit 0
fi

tmp_helper="$(mktemp)"
tmp_unit="$(mktemp)"
trap 'rm -f "$tmp_helper" "$tmp_unit"' EXIT

cat >"$tmp_helper" <<'EOF'
#!/bin/sh

set -u

log() {
  msg="$*"
  if command -v systemd-cat >/dev/null 2>&1; then
    printf '%s\n' "$msg" | systemd-cat -t mhi-sleep-hook
  elif command -v logger >/dev/null 2>&1; then
    logger -t mhi-sleep-hook -- "$msg"
  else
    printf '%s\n' "$msg" > /dev/kmsg 2>/dev/null || true
  fi
}

WWAN_IF="$(ip -o link show 2>/dev/null | awk -F': ' '$2 ~ /^wwan/ {print $2; exit}')"
if [ -z "${WWAN_IF}" ]; then WWAN_IF="wwan0"; fi

PCI_DEV=""
if [ -e "/sys/class/net/${WWAN_IF}/device" ]; then
  dev_path="$(readlink -f "/sys/class/net/${WWAN_IF}/device" 2>/dev/null || true)"
  if [ -n "$dev_path" ]; then
    PCI_DEV="$(printf '%s\n' "$dev_path" | sed -n 's|.*/\(0000:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]\.[0-9]\).*|\1|p')"
  fi
fi

# Fallback for known common location
if [ -z "$PCI_DEV" ] && [ -e /sys/bus/pci/devices/0000:08:00.0 ]; then
  PCI_DEV="0000:08:00.0"
fi

unbind_pci() {
  [ -n "$PCI_DEV" ] || return 1
  drv_path="$(readlink -f "/sys/bus/pci/devices/${PCI_DEV}/driver" 2>/dev/null || true)"
  [ -n "$drv_path" ] || return 1
  drv="$(basename "$drv_path" 2>/dev/null || true)"
  [ -n "$drv" ] || return 1
  if [ -w "/sys/bus/pci/drivers/${drv}/unbind" ]; then
    echo "$PCI_DEV" > "/sys/bus/pci/drivers/${drv}/unbind" 2>/dev/null || return 1
    return 0
  fi
  return 1
}

bind_pci_mhi() {
  [ -n "$PCI_DEV" ] || return 1
  if [ -w "/sys/bus/pci/drivers/mhi-pci-generic/bind" ]; then
    echo "$PCI_DEV" > /sys/bus/pci/drivers/mhi-pci-generic/bind 2>/dev/null || return 1
    return 0
  fi
  return 1
}

recover_modem() {
  # Full modem recovery: MM off, drop stale MBIM proxy, MHI SoC reset, MM on.
  # Needed when the MBIM channel wedges after resume: MM then logs
  # "NotOpened" or "could not grab port wwan0mbim0 ... unhandled port type" and
  # falls back to an AT-only modem that can never bring a bearer up.
  systemctl stop ModemManager.service 2>/dev/null
  pkill -x mbim-proxy 2>/dev/null || true
  # Controller node only (mhi0), not channel children like mhi0_DIAG.
  for r in /sys/bus/mhi/devices/mhi[0-9]/soc_reset /sys/bus/mhi/devices/mhi[0-9][0-9]/soc_reset; do
    [ -w "$r" ] || continue
    echo 1 > "$r" 2>/dev/null && log "recover: soc_reset via $r"
    sleep 3
    break
  done
  i=0
  while [ ! -e /dev/wwan0mbim0 ] && [ $i -lt 40 ]; do sleep 0.5; i=$((i+1)); done
  sleep 3
  systemctl start ModemManager.service 2>/dev/null
  log "recover: start ModemManager rc=$?"
}

mm_mbim_broken() {
  # $1 = journalctl --since timestamp
  journalctl -u ModemManager --since "$1" --no-pager -q 2>/dev/null \
    | grep -qE "NotOpened|could not grab port wwan0mbim0|unhandled port type"
}

phase="${1:-}"
case "$phase" in
  pre)
    log "pre: wwan_if=${WWAN_IF} pci_dev=${PCI_DEV}"
    # Stop MM before unloading mhi; otherwise MM/mbim-proxy keep a stale MBIM
    # channel and every post-resume connect fails with "MBIM protocol error: NotOpened".
    systemctl stop ModemManager.service 2>/dev/null
    log "pre: stop ModemManager rc=$?"
    pkill -x mbim-proxy 2>/dev/null || true
    rfkill block wwan 2>/dev/null || true
    ip link set "$WWAN_IF" down 2>/dev/null || true
    if unbind_pci; then log "pre: unbound ${PCI_DEV}"; else log "pre: unbind skipped/failed"; fi
    modprobe -r mhi_wwan_mbim mhi_wwan_ctrl mhi_pci_generic mhi 2>/dev/null
    log "pre: modprobe -r rc=$?"
    ;;
  post)
    log "post: wwan_if=${WWAN_IF} pci_dev=${PCI_DEV}"
    modprobe mhi_pci_generic 2>/dev/null
    log "post: modprobe mhi_pci_generic rc=$?"
    modprobe mhi_wwan_ctrl mhi_wwan_mbim 2>/dev/null
    log "post: modprobe mhi_wwan_* rc=$?"
    if bind_pci_mhi; then log "post: bound ${PCI_DEV}"; else log "post: bind skipped/failed"; fi
    rfkill unblock wwan 2>/dev/null || true
    # Let the MBIM port appear and the firmware settle before MM probes it;
    # probing too early leaves the modem in a state where every connect
    # returns "NotOpened".
    i=0
    while [ ! -e /dev/wwan0mbim0 ] && [ $i -lt 20 ]; do sleep 0.5; i=$((i+1)); done
    sleep 3
    systemctl start ModemManager.service 2>/dev/null
    log "post: start ModemManager rc=$?"
    # Detached watchdog: recover the modem if the MBIM channel wedges anyway.
    systemd-run --quiet --unit "mhi-wwan-watchdog-$(date +%s)" --collect \
      /usr/local/libexec/mhi-wwan-sleep watchdog 2>/dev/null
    ;;
  watchdog)
    since="$(date '+%Y-%m-%d %H:%M:%S')"
    recoveries=0
    n=0
    while [ $n -lt 20 ]; do
      sleep 15; n=$((n+1))
      state="$(nmcli -t -f GENERAL.STATE dev show wwan0mbim0 2>/dev/null | cut -d: -f2)"
      case "$state" in 100*) log "watchdog: connected after ${n}x15s (recoveries=${recoveries})"; exit 0 ;; esac
      if [ $recoveries -lt 2 ] && mm_mbim_broken "$since"; then
        recoveries=$((recoveries+1))
        log "watchdog: MBIM channel broken, recovering modem (#${recoveries})"
        recover_modem
        since="$(date '+%Y-%m-%d %H:%M:%S')"
      fi
    done
    log "watchdog: gave up, state=${state:-none}"
    ;;
  *)
    log "unknown phase: ${phase}"
    ;;
esac

exit 0
EOF

cat >"$tmp_unit" <<EOF
[Unit]
Description=Work around WWAN (mhi) suspend failure
Before=sleep.target
StopWhenUnneeded=yes

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${HELPER_PATH} pre
ExecStop=${HELPER_PATH} post

[Install]
WantedBy=sleep.target
EOF

sudo install -d -m 0755 "$HELPER_DIR"
sudo install -m 0755 "$tmp_helper" "$HELPER_PATH"
sudo install -m 0644 "$tmp_unit" "$SERVICE_PATH"

# Clean up legacy hook (not used by systemd 259)
sudo rm -f "$LEGACY_HOOK_PATH"

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"

echo "Installed: $HELPER_PATH"
echo "Installed: $SERVICE_PATH"
echo "Enabled: $SERVICE_NAME"
echo "Next: test with: systemctl suspend"
