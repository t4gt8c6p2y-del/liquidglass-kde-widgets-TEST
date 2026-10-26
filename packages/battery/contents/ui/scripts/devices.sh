#!/bin/sh
# Battery widget helper: prints what the widget needs, one record per line.
#
#   UPOWER|<kind>|<name>|<percent>|<state>|<power supply yes/no>
#   KDECONNECT|<type>|<name>|<percent>|<charging true/false>
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
            printf "UPOWER|%s|%s|%s|%s|%s\n", kind, model, pct, state, supply
    }
    /^Device:/ { flush(); dev = $2; kind = ""; model = ""; pct = ""; state = ""; supply = ""; next }
    /^Daemon:/ { flush(); dev = ""; next }
    dev == "" { next }
    /^  [a-z][a-z-]*[ \t]*$/ { kind = trim($0); next }
    /^  model:/        { model = val($0); next }
    /^  power supply:/ { supply = val($0); next }
    /^    state:/      { state = val($0); next }
    /^    percentage:/ { pct = val($0); sub(/%.*/, "", pct); next }
    END { flush() }
    '
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
