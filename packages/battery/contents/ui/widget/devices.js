.pragma library

// Turns the output of scripts/devices.sh into the data the widget draws.
//
//   parse(text) -> {
//       hasBattery: bool,      // does this computer have an internal battery?
//       percent:    int,       // computer battery 0..100 (0 when no battery)
//       charging:   bool,
//       powerSave:  bool,      // power-saver profile active => yellow ring
//       others:     [ { id, kind, name, percent, charging } ]
//   }
//
// `kind` is one of the glyph names understood by DeviceGlyph.qml:
//   laptop, desktop, phone, tablet, headphones, earbuds, mouse, keyboard, watch,
//   gamepad, speaker, generic

function _clamp(v) {
    v = parseInt(v)
    if (isNaN(v)) return -1
    return Math.max(0, Math.min(100, v))
}

function _isCharging(state) {
    return state === "charging" || state === "fully-charged" || state === "pending-charge"
}

// Picks a glyph from the name when the type alone says nothing useful
// (Bluetooth devices very often report "bluetooth-generic").
function _kindFromName(name) {
    const n = (name || "").toLowerCase()
    if (/airpod|buds|earbud|earphone|wf-1000/.test(n)) return "earbuds"
    if (/headphone|headset|wh-1000|beats|jabra|bose|max/.test(n)) return "headphones"
    if (/watch|band|fitbit|garmin/.test(n)) return "watch"
    if (/iphone|phone|pixel|galaxy|xiaomi|oneplus/.test(n)) return "phone"
    if (/ipad|tablet|tab /.test(n)) return "tablet"
    if (/mouse|mx master|trackpad|trackball/.test(n)) return "mouse"
    if (/keyboard|keychron|mx keys/.test(n)) return "keyboard"
    if (/controller|gamepad|dualsense|dualshock|xbox|joy-con|pro controller/.test(n)) return "gamepad"
    if (/speaker|soundbar|boom|charge [0-9]|flip [0-9]/.test(n)) return "speaker"
    return "generic"
}

function _upowerKind(kind, name) {
    switch (kind) {
    case "mouse":
    case "touchpad":       return "mouse"
    case "keyboard":       return "keyboard"
    case "phone":
    case "pda":            return "phone"
    case "tablet":         return "tablet"
    case "headset":
    case "headphones":
    case "other-audio":    {
        const k = _kindFromName(name)
        return k === "earbuds" ? "earbuds" : "headphones"
    }
    case "speakers":       return "speaker"
    case "gaming-input":   return "gamepad"
    case "wearable":       return "watch"
    default:               return _kindFromName(name)
    }
}

function _kdeConnectKind(type, name) {
    switch (type) {
    case "smartphone":     return "phone"
    case "tablet":         return "tablet"
    case "laptop":         return "laptop"
    case "desktop":        return "desktop"
    default:               return _kindFromName(name)
    }
}

function parse(text) {
    const res = {
        hasBattery: false,
        percent: 0,
        charging: false,
        powerSave: false,
        others: []
    }

    let pcSum = 0
    let pcCount = 0
    const seen = {}

    const lines = String(text || "").split("\n")
    for (let i = 0; i < lines.length; i++) {
        const f = lines[i].trim().split("|")
        if (f.length < 2) continue

        if (f[0] === "PROFILE") {
            res.powerSave = (f[1] || "").trim() === "power-saver"
            continue
        }

        if (f[0] === "UPOWER" && f.length >= 6) {
            const kind = f[1]
            const name = f[2]
            const pct = _clamp(f[3])
            const state = f[4]
            const supply = f[5] === "yes"
            if (pct < 0) continue

            if (kind === "battery" && supply) {
                // The computer's own battery (average when there are several).
                pcSum += pct
                pcCount++
                if (_isCharging(state)) res.charging = true
                continue
            }
            // Not a peripheral we can show.
            if (kind === "ups" || kind === "monitor" || kind === "line-power") continue

            const id = "up:" + kind + ":" + name
            if (seen[id]) continue
            seen[id] = true
            res.others.push({
                id: id,
                kind: _upowerKind(kind, name),
                name: name,
                percent: pct,
                charging: _isCharging(state)
            })
            continue
        }

        if (f[0] === "KDECONNECT" && f.length >= 5) {
            const pct = _clamp(f[3])
            if (pct < 0) continue
            const id = "kc:" + f[2]
            if (seen[id]) continue
            seen[id] = true
            res.others.unshift({           // phones first, like on iOS
                id: id,
                kind: _kdeConnectKind(f[1], f[2]),
                name: f[2],
                percent: pct,
                charging: f[4] === "true"
            })
        }
    }

    // An iPhone/iPad read directly over USB / Wi-Fi is the freshest source:
    // it replaces any Bluetooth entry for the same device.
    for (let j = 0; j < lines.length; j++) {
        const g = lines[j].trim().split("|")
        if (g[0] !== "IDEVICE" || g.length < 5) continue
        const pct = _clamp(g[3])
        if (pct < 0) continue
        const nm = (g[2] || "").toLowerCase()
        const phone = g[1] !== "iPad"
        res.others = res.others.filter(o => !(o.name.toLowerCase() === nm && (o.kind === "phone" || o.kind === "tablet")))
        res.others.unshift({
            id: "id:" + g[2],
            kind: phone ? "phone" : "tablet",
            name: g[2],
            percent: pct,
            charging: g[4] === "true"
        })
    }

    if (pcCount > 0) {
        res.hasBattery = true
        res.percent = Math.round(pcSum / pcCount)
    }
    return res
}
