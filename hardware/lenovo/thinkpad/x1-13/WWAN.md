# WWAN (Quectel RM520N-GL / MHI) Notes

This machine class: ThinkPad X1 Carbon Gen 13 with internal Quectel RM520N-GL.

Hardware/driver stack (observed):

- PCI device: 0000:08:00.0
- Kernel driver: mhi-pci-generic
- Data path: mhi_wwan_mbim (MBIM over MHI)
- Net interface: wwan0
- MBIM control: /dev/wwan0mbim0

## Recommended management stack

Use ModemManager + NetworkManager for WWAN.

If the system already uses systemd-networkd/iwd for Wi-Fi/Ethernet, keep them and
ensure only one network manager touches each interface:

- NetworkManager: manage only WWAN devices
- systemd-networkd: ignore ww* links

`setup-wwan-docomo.sh install` writes:

- /etc/NetworkManager/conf.d/10-wwan-only.conf
- /etc/systemd/network/10-wwan-unmanaged.network

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
bash hardware/lenovo/thinkpad/x1-13/setup-wwan-docomo.sh enable --wait 60 --direct-mbim
```

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
