# WWAN (MHI/MBIM) Notes

Machine classes covered:

- ThinkPad X1 Carbon Gen 13: Quectel RM520N-GL (PCI `1eac:*`)
- ThinkPad X1 Carbon Gen 14: Foxconn T99W696 (PCI `17cb:0308`), see the FCC lock section

`setup-wwan-docomo.sh` detects the modem via PCI id and picks the matching radio-enable path.

Hardware/driver stack (observed):

- PCI device: 0000:08:00.0
- Kernel driver: mhi-pci-generic
- Data path: mhi_wwan_mbim (MBIM over MHI)
- Net interface: wwan0
- MBIM control: /dev/wwan0mbim0

## Recommended management stack

Use ModemManager + NetworkManager for WWAN. Omarchy already runs NetworkManager
for Wi-Fi and Ethernet (systemd-networkd is retired), so WWAN is one more
NetworkManager device.

Older versions of `setup-wwan-docomo.sh` split interfaces between NetworkManager
(WWAN only) and systemd-networkd/iwd (Wi-Fi/Ethernet) by writing:

- /etc/NetworkManager/conf.d/10-wwan-only.conf
- /etc/systemd/network/10-wwan-unmanaged.network

With systemd-networkd retired, that split leaves Ethernet unmanaged (no link, no
DHCP). `setup-wwan-docomo.sh install` and `uninstall` remove both files when they
carry the hey-omarchy marker.

## Failure mode: "software radio switch is OFF" (RM520N-GL)

Symptoms:

- `nmcli connection up docomo` fails almost immediately:
  - `Disconnected by user`
  - or `No suitable device found` (if ModemManager is restarting / WWAN device not ready)
- ModemManager logs show:
  - `Cannot power-up: sotware radio switch is OFF` (typo is in upstream log string)
  - `failed enabling modem: Invalid transition`

In this state, generic MBIM Basic Connect radio control may not flip the software
radio:

- `mbimcli ... --set-radio-state=on` reports success but `Software radio state` stays `off`.

### Detect

```sh
sudo journalctl -u ModemManager -b --no-pager | tail -n 120
sudo rfkill list wwan
sudo mmcli -L
sudo mmcli -m 0
```

Radio state (proxy vs direct):

```sh
# via mbim-proxy (ModemManager running)
sudo mbimcli -d /dev/wwan0mbim0 -p --query-radio-state

# direct (stop ModemManager temporarily)
sudo systemctl stop ModemManager
sudo mbimcli -d /dev/wwan0mbim0 --query-radio-state
sudo systemctl start ModemManager
```

### Fix: use Quectel MBIM service to enable software radio

On RM520N-GL, the reliable fix was Quectel vendor service:

- `mbimcli --quectel-set-radio-state=on`

Manual sequence:

```sh
sudo systemctl stop ModemManager
sudo mbimcli -d /dev/wwan0mbim0 --quectel-set-radio-state=on
sudo mbimcli -d /dev/wwan0mbim0 --query-radio-state
sudo systemctl start ModemManager

sudo nmcli connection up docomo
```

`setup-wwan-docomo.sh enable --direct-mbim` automates:

- rfkill unblock
- Basic Connect `--set-radio-state=on`
- fallbacks: OFF->ON toggle, MBIMEx open variants, Quectel `--quectel-set-radio-state=on`
- optional last-resort: MHI `soc_reset`

## X1 Carbon Gen 14 (Foxconn T99W696, PCI 17cb:0308 / subsys 105b:e143): FCC lock

Gen 14 ships a Foxconn T99W696 (SDX61), not the Quectel RM520N-GL. The same
`Cannot power-up: sotware radio switch is OFF` / `Invalid transition` loop appears,
but `--direct-mbim` cannot fix it: the Quectel MBIM service is absent and the real
cause is the FCC lock. The radio stays off until the host sends Foxconn's
vendor unlock after every modem power-on. ModemManager ships no unlock for this id
(`fcc-unlock.available.d/105b` only covers SDX55 `e0ab`/`e0c3`).

Fix (observed working, 2026-10-08, modemmanager 1.24.2). `setup-wwan-docomo.sh install`
and `enable` do this automatically when they detect `17cb:0308`; manual equivalent:

```sh
yay -S lenovo-wwan-unlock            # installs /usr/lib/ModemManager/fcc-unlock.d/17cb:0308
sudo systemctl enable --now lenovo-cfgservice.service
sudo systemctl restart ModemManager
nmcli connection up docomo
```

Verify the unlock ran: `journalctl -t DPR_Fcc_unlock_service -b` should show
`FCC unlock is success`. ModemManager then runs it automatically on boot/resume.
The unlock is gated on a non-US SIM (docomo passes). Open alternative without
Lenovo blobs: https://github.com/twh/wwan-unlock (`foxunlock`, FOXAP 0xE4 msg 0x5571).

## Suspend/resume behavior (with mhi-wwan-sleep.service)

If you installed the suspend workaround (`mhi-wwan-sleep.service`), it will:

- block WWAN via rfkill
- unload/unbind MHI

This is required to avoid the suspend failure, but it also means the data session
will drop every suspend. After resume you'll typically see:

- `wwan0` in `state DOWN`
- `nmcli` shows `wwan0mbim0` as `disconnected`

### Auto-reconnect after resume

Autoconnect is enabled by default by `setup-wwan-docomo.sh install`.

To enable (or re-enable) explicitly:

```sh
sudo nmcli connection modify docomo connection.autoconnect yes connection.autoconnect-retries 0
```

To disable (manual connect only):

```sh
sudo nmcli connection modify docomo connection.autoconnect no
```

If it still doesn't come back (e.g. software radio switch flips OFF again), run:

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-wwan-docomo.sh enable --wait 60
```

(`--direct-mbim` only changes behaviour on Quectel; on T99W696 the script re-runs the FCC unlock.)

## Connectivity check

```sh
nmcli -t -f NAME,TYPE,DEVICE connection show --active
nmcli device show wwan0mbim0

# Verify the path specifically via WWAN
curl -4 --interface wwan0 --max-time 10 http://connectivitycheck.gstatic.com/generate_204 \
  -o /dev/null -w '%{http_code}\n'
```

## Routing / priority

The script sets `ipv4.route-metric=700` so Wi-Fi (often metric 600) stays preferred.

To prefer WWAN, lower the metric:

```sh
sudo nmcli connection modify docomo ipv4.route-metric 500 ipv6.route-metric 500
sudo nmcli connection down docomo && sudo nmcli connection up docomo
```

## systemd-rfkill persistence

systemd-rfkill restores RFKILL state at boot from `/var/lib/systemd/rfkill/`.
If WWAN keeps coming up blocked, check:

```sh
rfkill list wwan
sudo journalctl -u systemd-rfkill -b --no-pager
```

## MHI SoC reset (last resort)

If MBIM commands start timing out and the modem wedges:

```sh
echo 1 | sudo tee /sys/bus/mhi/devices/mhi0/soc_reset
```

Then re-run the enable step.
