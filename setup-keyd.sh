#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ASSETS=(kana-hyper.conf roba-hyper.conf hyper)
STATES=(.hey-omarchy-kana-hyper .hey-omarchy-roba-hyper .hey-omarchy-hyper)
DRY_RUN=0
ROLLBACK=0

log() { printf '%s\n' "$*" >&2; }
ts() { date +%Y%m%d-%H%M%S; }
fail() { log "ERROR: $*"; exit 1; }
hash() { sha256sum "$1" | cut -d ' ' -f 1; }

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --rollback) ROLLBACK=1 ;;
    -h|--help)
      log "Usage: bash setup-keyd.sh [--dry-run] [--rollback]"
      exit 0 ;;
    *) fail "Unknown option: $arg" ;;
  esac
done

if (( DRY_RUN )); then
  for asset in "${ASSETS[@]}"; do
    if (( ROLLBACK )); then
      log "[dry-run] restore the recorded backup or remove unchanged bundle-created /etc/keyd/$asset; preserve unowned/user-modified files"
    else
      log "[dry-run] back up changed /etc/keyd/$asset as *.bak.YYYYmmdd-HHMMSS and install $ROOT/etc/keyd/$asset; do not claim identical files"
    fi
  done
  if (( ROLLBACK )); then
    log "[dry-run] refuse the transaction if changing shared hyper could affect retained include consumers; reload keyd only if active"
  else
    log "[dry-run] keyd check both configurations with the bundled hyper include expanded, before installing any assets"
    log "[dry-run] install all three assets as one transaction; systemctl enable --now keyd.service; keyd reload"
  fi
  exit 0
fi

if (( EUID != 0 )); then
  command -v sudo >/dev/null 2>&1 || fail "sudo is required to configure /etc/keyd"
  exec sudo bash "$ROOT/setup-keyd.sh" "$@"
fi

# Keep the legacy kana record's two-line backup-path/hash format for every asset.
# Inspect these root-owned records only after the single privilege escalation.
previous=()
installed_hash=()
for i in "${!ASSETS[@]}"; do
  dest="/etc/keyd/${ASSETS[i]}"
  state="/etc/keyd/${STATES[i]}"
  previous[i]=absent
  installed_hash[i]=""
  if [[ -e "$state" || -L "$state" ]]; then
    [[ -f "$state" && ! -L "$state" ]] || fail "Not a regular ownership record: $state"
    mapfile -t record < "$state"
    [[ ${#record[@]} -eq 2 && ${record[1]} =~ ^[0-9a-f]{64}$ ]] || fail "Invalid ownership record: $state"
    previous[i]="${record[0]}"
    installed_hash[i]="${record[1]}"
    if [[ "${previous[i]}" != absent ]]; then
      [[ "${previous[i]}" == "$dest.bak."* && "${previous[i]#"$dest.bak."}" =~ ^[0-9]{8}-[0-9]{6}$ ]] || fail "Invalid backup path in $state"
    fi
  fi
done

selected=()
if (( ROLLBACK )); then
  for i in "${!ASSETS[@]}"; do
    dest="/etc/keyd/${ASSETS[i]}"
    if [[ -z "${installed_hash[i]}" ]]; then
      log "skip: $dest (no bundle ownership record)"
    elif [[ ! -f "$dest" ]] || [[ "$(hash "$dest")" != "${installed_hash[i]}" ]]; then
      log "skip: $dest changed since apply; preserving the user's keyd configuration and ownership record"
    else
      if [[ "${previous[i]}" != absent ]]; then
        [[ -f "${previous[i]}" ]] || fail "Missing or invalid keyd backup: ${previous[i]}; leaving the bundle unchanged"
      fi
      selected+=("$i")
    fi
  done
  (( ${#selected[@]} )) || exit 0

  # A restored backup can itself be an include consumer. Check the configuration
  # that would survive, not merely the current files. Refuse unknown/transitive
  # includes too: a successful parse does not prove unchanged Hyper semantics.
  for i in "${selected[@]}"; do
    [[ "${ASSETS[i]}" == hyper ]] || continue
    if [[ "${previous[i]}" != absent ]] && cmp -s /etc/keyd/hyper "${previous[i]}"; then
      continue
    fi
    shopt -s nullglob
    for config in /etc/keyd/*.conf; do
      candidate="$config"
      for j in "${selected[@]}"; do
        if [[ "$config" == "/etc/keyd/${ASSETS[j]}" ]]; then
          candidate="${previous[j]}"
          break
        fi
      done
      [[ "$candidate" != absent ]] || continue
      [[ -f "$candidate" ]] || fail "Cannot inspect retained config $config; refusing shared hyper rollback"
      while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*include[[:space:]] ]]; then
          fail "Refusing rollback: retained $config has an include which may depend on shared /etc/keyd/hyper; no bundle files were changed"
        fi
      done < "$candidate"
    done
    shopt -u nullglob
  done
else
  for i in "${!ASSETS[@]}"; do
    source="$ROOT/etc/keyd/${ASSETS[i]}"
    dest="/etc/keyd/${ASSETS[i]}"
    [[ -f "$source" ]] || fail "Missing source file: $source"
    [[ ! -e "$dest" && ! -L "$dest" || -f "$dest" ]] || fail "Not a regular keyd configuration: $dest"
    if [[ -f "$dest" ]] && cmp -s "$source" "$dest"; then
      log "ok: $dest"
    else
      selected+=("$i")
    fi
  done
fi

command -v keyd >/dev/null 2>&1 || fail "keyd is required; install keyd before applying keyboard defaults"
command -v systemctl >/dev/null 2>&1 || fail "systemctl is required to manage keyd.service"

mkdir -p /etc/keyd
work="$(mktemp -d /etc/keyd/.hey-omarchy-transaction.XXXXXX)"
changed=()
record_changed=()
before=()
complete=0
restore_failed_transaction() {
  local status=$? i dest state recovery_failed=0
  trap - EXIT
  set +e
  if (( ! complete )); then
    for i in "${changed[@]}"; do
      dest="/etc/keyd/${ASSETS[i]}"
      if [[ "${before[i]}" == absent ]]; then
        rm -f -- "$dest" || recovery_failed=1
      else
        cp -a --remove-destination "${before[i]}" "$dest" || recovery_failed=1
      fi
    done
    for i in "${record_changed[@]}"; do
      state="/etc/keyd/${STATES[i]}"
      if [[ -f "$work/record-before-$i" ]]; then
        cp -a --remove-destination "$work/record-before-$i" "$state" || recovery_failed=1
      else
        rm -f -- "$state" || recovery_failed=1
      fi
    done
    if (( ${#changed[@]} )); then
      if systemctl is-active --quiet keyd.service; then
        keyd reload || log "WARNING: keyd could not reload the restored configuration"
      fi
      if (( recovery_failed )); then
        log "ERROR: could not fully restore the prior keyd bundle; recovery files retained in $work and the reported backups"
      else
        log "ERROR: keyd transaction failed; restored prior configurations and ownership records"
      fi
    fi
  fi
  (( recovery_failed )) || rm -rf -- "$work"
  exit "$status"
}
trap restore_failed_transaction EXIT

if (( ! ROLLBACK )); then
  # keyd resolves includes from /etc/keyd, even when checking another path.
  # Flatten only our known include so validation cannot accidentally use an old
  # host-side hyper. Reject unexpected includes rather than checking host data.
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ ! "$line" =~ ^[[:space:]]*include[[:space:]] ]] || fail "Unexpected nested include in bundled hyper"
  done < "$ROOT/etc/keyd/hyper"
  for asset in kana-hyper.conf roba-hyper.conf; do
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^[[:space:]]*include[[:space:]] ]]; then
        [[ "$line" =~ ^[[:space:]]*include[[:space:]]+hyper[[:space:]]*$ ]] || fail "Unexpected include in bundled $asset: $line"
        cat "$ROOT/etc/keyd/hyper"
        printf '\n'
      else
        printf '%s\n' "$line"
      fi
    done < "$ROOT/etc/keyd/$asset" > "$work/$asset.check"
    keyd check "$work/$asset.check"
  done
fi

stamp="$(ts)"
# Prepare every backup and prospective record before replacing any configuration.
for i in "${selected[@]}"; do
  dest="/etc/keyd/${ASSETS[i]}"
  state="/etc/keyd/${STATES[i]}"
  before[i]=absent
  [[ ! -f "$state" ]] || cp -a "$state" "$work/record-before-$i"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if (( ROLLBACK )); then
      before[i]="$dest.bak.rollback.$stamp"
    else
      before[i]="$dest.bak.$stamp"
    fi
    [[ ! -e "${before[i]}" && ! -L "${before[i]}" ]] || fail "Backup already exists: ${before[i]}; retry after one second"
    cp -a "$dest" "${before[i]}"
    log "backup: $dest -> ${before[i]}"
  fi
  if (( ! ROLLBACK )); then
    # Updating an unchanged owned file retains its original rollback baseline.
    # Reapplying over a user edit instead backs up that edit as the new baseline.
    if [[ -z "${installed_hash[i]}" || ! -f "$dest" ]] || [[ "$(hash "$dest")" != "${installed_hash[i]}" ]]; then
      previous[i]="${before[i]}"
    fi
    [[ "${previous[i]}" == absent || -f "${previous[i]}" ]] || fail "Missing or invalid keyd backup: ${previous[i]}"
    printf '%s\n%s\n' "${previous[i]}" "$(hash "$ROOT/etc/keyd/${ASSETS[i]}")" > "$work/record-$i"
    chmod 0600 "$work/record-$i"
    install -m 0644 "$ROOT/etc/keyd/${ASSETS[i]}" "$work/install-$i"
  elif [[ "${previous[i]}" != absent ]]; then
    cp -a "${previous[i]}" "$work/install-$i"
  fi
done

for i in "${selected[@]}"; do
  dest="/etc/keyd/${ASSETS[i]}"
  changed+=("$i")
  if (( ROLLBACK )) && [[ "${previous[i]}" == absent ]]; then
    rm -- "$dest"
  else
    mv -T "$work/install-$i" "$dest"
  fi
done

if (( ROLLBACK )); then
  if systemctl is-active --quiet keyd.service; then
    keyd reload
  fi
else
  systemctl enable --now keyd.service
  keyd reload
  systemctl is-active --quiet keyd.service
fi

# Do not claim identical preexisting files, and commit ownership only after the
# complete bundle is accepted. The EXIT handler also undoes a partial commit.
for i in "${selected[@]}"; do
  state="/etc/keyd/${STATES[i]}"
  record_changed+=("$i")
  if (( ROLLBACK )); then
    rm -- "$state"
  else
    mv -T "$work/record-$i" "$state"
  fi
done
complete=1
if (( ROLLBACK )); then
  log "keyd bundle rolled back; unowned/user-modified files preserved and keyd service left enabled"
else
  log "keyd ready: built-in kana and roBa/moNa2 Right Meta share Hyper (Ctrl+Alt+Shift+Super)"
  log "Kana taps Enter; Henkan taps Backspace / holds Shift; Muhenkan preserves tap / holds Shift (tap <200 ms)"
  log "A taps normally / holds Ctrl after 250 ms; typing within 200 ms keeps A literal"
fi
