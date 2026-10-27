#!/bin/sh
# Battery widget helper: prints what the widget needs, one record per line.
#
#   UPOWER|<kind>|<name>|<percent>|<state>|<power supply yes/no>
#   KDECONNECT|<type>|<name>|<percent>|<charging true/false>
#   IDEVICE|<class>|<name>|<percent>|<charging true/false>   (iPhone/iPad, libimobiledevice)
#   PROFILE|<power-saver|balanced|performance>
#
# Everything is best effort: a missing tool or an unreachable device simply
# produces no line. The widget runs this with `sh <file>` (no exec bit needed).

export LC_ALL=C

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

# ── iPhone / iPad (libimobiledevice: USB cable, or Wi-Fi sync) ─────────────
# Optional, and the most reliable way to get a fresh iPhone level on Linux.
if command -v idevice_id >/dev/null 2>&1 && command -v ideviceinfo >/dev/null 2>&1; then
    T=""; command -v timeout >/dev/null 2>&1 && T="timeout 4"
    seen=" "
    for net in "" "-n"; do
        for udid in $($T idevice_id $net -l 2>/dev/null; [ -n "$net" ] && $T idevice_id -n 2>/dev/null); do
            case "$seen" in *" $udid "*) continue ;; esac
            seen="$seen$udid "
            bat=$($T ideviceinfo $net -u "$udid" -q com.apple.mobile.battery 2>/dev/null)
            pct=$(echo "$bat" | awk -F': *' '/^BatteryCurrentCapacity:/ {print $2}')
            [ -z "$pct" ] && continue
            chg=$(echo "$bat" | awk -F': *' '/^BatteryIsCharging:/ {print $2}')
            name=$($T ideviceinfo $net -u "$udid" -k DeviceName 2>/dev/null)
            class=$($T ideviceinfo $net -u "$udid" -k DeviceClass 2>/dev/null)
            echo "IDEVICE|$class|$name|$pct|$chg"
        done
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
