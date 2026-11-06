#!/bin/bash
# Battery widget helper: prints what the widget needs, one record per line.
#
#   devices.sh          print the records now
#   devices.sh --wait   sleep (no CPU, no polling) until a battery level or
#                       charging state changes on D-Bus (UPower, BlueZ,
#                       KDE Connect), then print the records
#
#   UPOWER|<kind>|<name>|<percent>|<state>|<power supply yes/no>
#   KDECONNECT|<type>|<name>|<percent>|<charging true/false>
#   PROFILE|<power-saver|balanced|performance>
#
# Everything is best effort: a missing tool or an unreachable device simply
# produces no line. The widget runs this with `sh <file>` (no exec bit needed).

export LC_ALL=C

# ── --wait: block until something battery related changes ──────────────────
wait_for_change() {
    if ! command -v dbus-monitor >/dev/null 2>&1; then
        # No way to listen: fall back to a slow check every 5 minutes.
        sleep 300
        return
    fi
    local fifo
    fifo=$(mktemp -u "${XDG_RUNTIME_DIR:-/tmp}/lg-battery.XXXXXX") || { sleep 300; return; }
    mkfifo "$fifo" || { sleep 300; return; }
    trap 'pkill -P $$ 2>/dev/null; rm -f "$fifo"' EXIT TERM INT

    # System bus: UPower + BlueZ, only when a level/state/connection changes.
    dbus-monitor --system \
        "type='signal',sender='org.freedesktop.UPower',member='PropertiesChanged'" \
        "type='signal',sender='org.bluez',member='PropertiesChanged'" 2>/dev/null \
        | grep --line-buffered -m1 -E 'string "(Percentage|State|Connected)"' > "$fifo" &
    # Session bus: KDE Connect battery signals.
    dbus-monitor --session \
        "type='signal',interface='org.kde.kdeconnect.device.battery'" 2>/dev/null \
        | grep --line-buffered -m1 '^signal' > "$fifo" &

    read -r _ < "$fifo"
    pkill -P $$ 2>/dev/null
    rm -f "$fifo"
    trap - EXIT TERM INT
    # Let the burst of signals settle, and never fire more than once per 2 s.
    sleep 2
}

if [ "$1" = "--wait" ]; then
    wait_for_change
fi

# ── Internal battery + Bluetooth / USB peripherals (UPower) ────────────────
if command -v upower >/dev/null 2>&1; then
    upower --dump 2>/dev/null | awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function val(s)  { sub(/^[^:]*:/, "", s); return trim(s) }
    function flush() {
        if (dev != "" && dev !~ /DisplayDevice/ && kind != "" && kind != "line-power" && pct != "")
            printf "UPOWER|%s|%s|%s|%s|%s|%s\n", kind, model, pct, state, supply, npath
    }
    /^Device:/ { flush(); dev = $2; kind = ""; model = ""; pct = ""; state = ""; supply = ""; npath = ""; next }
    /^Daemon:/ { flush(); dev = ""; next }
    dev == "" { next }
    /^  [a-z][a-z-]*[ \t]*$/ { kind = trim($0); next }
    /^  native-path:/  { npath = val($0); next }
    /^  model:/        { model = val($0); next }
    /^  power supply:/ { supply = val($0); next }
    /^    state:/      { state = val($0); next }
    /^    percentage:/ { pct = val($0); sub(/%.*/, "", pct); next }
    END { flush() }
    ' | while IFS='|' read -r tag kind model pct state supply npath; do
        # Bluetooth devices: UPower keeps a stale entry (and a stale level)
        # after a disconnect. Skip devices BlueZ says are not connected and
        # prefer BlueZ's own, fresher battery value.
        # Cable-connected devices are not shown: a phone / tablet that is not
        # a Bluetooth device (USB), or anything UPower reports on a USB path
        # other than receivers of wireless mice / keyboards (hidpp).
        case "$npath" in
        /org/bluez/*) ;;
        *)
            case "$kind" in
            phone|pda|tablet|media-player) continue ;;
            esac
            case "$npath" in
            *hidpp*|*bluetooth*) ;;
            */usb*|*usbmux*|*idevice*) [ "$kind" = "battery" ] || continue ;;
            esac
            ;;
        esac
        case "$npath" in
        /org/bluez/*)
            if command -v busctl >/dev/null 2>&1; then
                conn=$(busctl --system get-property org.bluez "$npath" org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}')
                [ "$conn" = "false" ] && continue
                fresh=$(busctl --system get-property org.bluez "$npath" org.bluez.Battery1 Percentage 2>/dev/null | awk '{print $2}')
                [ -n "$fresh" ] && pct=$fresh
            fi
            ;;
        esac
        echo "$tag|$kind|$model|$pct|$state|$supply"
    done
fi

# ── Phones / tablets paired with KDE Connect ───────────────────────────────
if command -v kdeconnect-cli >/dev/null 2>&1 && command -v busctl >/dev/null 2>&1; then
    for id in $(kdeconnect-cli -a --id-only 2>/dev/null); do
        base="/modules/kdeconnect/devices/$id"
        charge=$(busctl --user get-property org.kde.kdeconnect "$base/battery" org.kde.kdeconnect.device.battery charge 2>/dev/null | awk '{print $2}')
        [ -z "$charge" ] && continue
        [ "$charge" -ge 0 ] 2>/dev/null || continue
        charging=$(busctl --user get-property org.kde.kdeconnect "$base/battery" org.kde.kdeconnect.device.battery isCharging 2>/dev/null | awk '{print $2}')
        name=$(busctl --user get-property org.kde.kdeconnect "$base" org.kde.kdeconnect.device name 2>/dev/null | sed 's/^s "\(.*\)"$/\1/')
        type=$(busctl --user get-property org.kde.kdeconnect "$base" org.kde.kdeconnect.device type 2>/dev/null | sed 's/^s "\(.*\)"$/\1/')
        echo "KDECONNECT|$type|$name|$charge|$charging"
    done
fi

# ── Power profile (power-saver => yellow ring) ─────────────────────────────
profile=""
if command -v powerprofilesctl >/dev/null 2>&1; then
    profile=$(powerprofilesctl get 2>/dev/null)
fi
if [ -z "$profile" ] && command -v busctl >/dev/null 2>&1; then
    profile=$(busctl --system get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile 2>/dev/null | sed 's/^s "\(.*\)"$/\1/')
    [ -z "$profile" ] && profile=$(busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null | sed 's/^s "\(.*\)"$/\1/')
fi
echo "PROFILE|$profile"
