import QtQuick

// Outline device icon drawn on a 100x100 grid so it scales with the ring and
// takes its colour from the theme (`color`). Same stroke style as the phone
// icon of the iOS Batteries widget: rounded caps, uniform line width.
Canvas {
    id: glyph

    // laptop, desktop, phone, tablet, headphones, earbuds, mouse, keyboard, watch,
    // gamepad, speaker, generic
    property string kind: "generic"
    property color color: "#ffffff"

    // Canvas doesn't repaint on bound property changes by itself.
    onKindChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function _rrect(ctx, x, y, w, h, r) {
        r = Math.min(r, w / 2, h / 2)
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y)
        ctx.arcTo(x + w, y, x + w, y + r, r)
        ctx.lineTo(x + w, y + h - r)
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
        ctx.lineTo(x + r, y + h)
        ctx.arcTo(x, y + h, x, y + h - r, r)
        ctx.lineTo(x, y + r)
        ctx.arcTo(x, y, x + r, y, r)
        ctx.closePath()
    }
    function _line(ctx, x1, y1, x2, y2) {
        ctx.beginPath()
        ctx.moveTo(x1, y1)
        ctx.lineTo(x2, y2)
        ctx.stroke()
    }
    function _dot(ctx, x, y, r) {
        ctx.beginPath()
        ctx.arc(x, y, r, 0, Math.PI * 2)
        ctx.fill()
    }

    // Translucent body fill, like the iOS icons (outline + softly filled face).
    function _soft(ctx, a) {
        ctx.save()
        ctx.globalAlpha = a
        ctx.fill()
        ctx.restore()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const s = Math.min(width, height)
        if (s <= 0) return

        ctx.save()
        ctx.translate((width - s) / 2, (height - s) / 2)
        ctx.scale(s / 100, s / 100)
        ctx.strokeStyle = glyph.color
        ctx.fillStyle = glyph.color
        ctx.lineWidth = 5.5
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        switch (glyph.kind) {
        case "phone":
            // iPhone: thick bezel, softly filled screen, notch + home bar
            ctx.lineWidth = 7
            _rrect(ctx, 27.5, 5.5, 45, 89, 11); _soft(ctx, 0.28); ctx.stroke()
            _rrect(ctx, 39, 11, 22, 6, 3); ctx.fill()
            _rrect(ctx, 38, 84, 24, 4.6, 2.3); ctx.fill()
            break
        case "tablet":
            _rrect(ctx, 14, 6, 72, 88, 9); ctx.stroke()
            _line(ctx, 41, 84, 59, 84)
            break

        case "laptop":
            // MacBook: thick bezel, softly filled screen with notch, slim base
            ctx.lineWidth = 7
            _rrect(ctx, 16.5, 21.5, 67, 44, 6); _soft(ctx, 0.30); ctx.stroke()
            _rrect(ctx, 41, 21, 18, 6, 3); ctx.fill()
            ctx.beginPath()
            ctx.moveTo(5, 70)
            ctx.lineTo(95, 70)
            ctx.lineTo(95, 73)
            ctx.arcTo(95, 79, 89, 79, 6)
            ctx.lineTo(11, 79)
            ctx.arcTo(5, 79, 5, 73, 6)
            ctx.closePath()
            ctx.fill()
            break
        case "desktop":
            _rrect(ctx, 10, 12, 80, 54, 6); ctx.stroke()
            _line(ctx, 50, 66, 50, 82)
            _line(ctx, 32, 87, 68, 87)
            break

        case "headphones":
            // Over-ear headphones: thick band + filled ear cups
            ctx.lineWidth = 8
            ctx.beginPath()
            ctx.arc(50, 52, 33, Math.PI * 1.02, Math.PI * -0.02, false)
            ctx.stroke()
            _rrect(ctx, 11, 50, 22, 40, 11); ctx.fill()
            _rrect(ctx, 67, 50, 22, 40, 11); ctx.fill()
            break

        case "earbuds":
            // AirPods: two round heads with stems
            for (let i = 0; i < 2; i++) {
                const x = i === 0 ? 33 : 67
                const sx = i === 0 ? x - 1 : x + 1
                ctx.beginPath(); ctx.arc(x, 34, 17, 0, Math.PI * 2); ctx.fill()
                _rrect(ctx, sx - 5.5 + (i === 0 ? -4 : 4), 36, 11, 52, 5.5); ctx.fill()
            }
            break
        case "mouse":
            _rrect(ctx, 27, 5, 46, 90, 23); ctx.stroke()
            _line(ctx, 50, 6, 50, 38)
            break

        case "keyboard":
            _rrect(ctx, 4, 24, 92, 52, 9); ctx.stroke()
            for (let r = 0; r < 2; r++)
                for (let c = 0; c < 5; c++)
                    _dot(ctx, 20 + c * 15, 39 + r * 12, 2.6)
            _line(ctx, 30, 64, 70, 64)
            break

        case "watch":
            _rrect(ctx, 24, 25, 52, 50, 14); ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(36, 25); ctx.lineTo(40, 6); ctx.lineTo(60, 6); ctx.lineTo(64, 25)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(36, 75); ctx.lineTo(40, 94); ctx.lineTo(60, 94); ctx.lineTo(64, 75)
            ctx.stroke()
            break

        case "gamepad":
            _rrect(ctx, 4, 26, 92, 50, 24); ctx.stroke()
            _line(ctx, 22, 51, 36, 51)
            _line(ctx, 29, 44, 29, 58)
            _dot(ctx, 68, 45, 3.6)
            _dot(ctx, 78, 55, 3.6)
            break

        case "speaker":
            _rrect(ctx, 23, 5, 54, 90, 11); ctx.stroke()
            ctx.beginPath(); ctx.arc(50, 64, 15, 0, Math.PI * 2); ctx.stroke()
            _dot(ctx, 50, 26, 5)
            break

        default:    // generic: battery outline
            _rrect(ctx, 6, 29, 78, 42, 9); ctx.stroke()
            _rrect(ctx, 88, 42, 6, 16, 3); ctx.fill()
            break
        }
        ctx.restore()
    }
}
