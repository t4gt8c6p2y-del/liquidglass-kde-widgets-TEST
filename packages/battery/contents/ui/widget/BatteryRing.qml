import QtQuick

// A battery ring like the iOS Batteries widget: a faint full track, a rounded
// arc starting at 12 o'clock and running clockwise, and the device icon in the
// middle. While charging, a lightning bolt sits in a gap at the top of the
// ring. With `empty: true` only the track is drawn (free slot).
Item {
    id: ring

    property real level: 0            // 0..1, animated
    property bool empty: false
    property bool charging: false
    property string kind: "generic"
    property color arcColor: "#34C759"
    property color trackColor: Qt.rgba(1, 1, 1, 0.2)
    property color glyphColor: "#ffffff"

    // Ring thickness relative to its diameter.
    readonly property real thickness: 0.085
    // Icon box relative to the ring diameter.
    readonly property real glyphScale: 0.52

    Behavior on level { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    // Canvas doesn't repaint on bound property changes by itself.
    onLevelChanged: arc.requestPaint()
    onArcColorChanged: arc.requestPaint()
    onTrackColorChanged: arc.requestPaint()
    onEmptyChanged: arc.requestPaint()
    onChargingChanged: arc.requestPaint()

    // Drawing area is a bit larger than the ring so the bolt can stick out of
    // the ring's top edge without being clipped.
    readonly property real pad: Math.min(width, height) * 0.08

    CrispCanvas {
        id: arc
        anchors.fill: parent
        anchors.margins: -ring.pad

        onPaint: (ctx) => {
            const d = Math.min(width, height) - 2 * ring.pad
            if (d <= 0) return

            const lw = d * ring.thickness
            const r = (d - lw) / 2
            const cx = width / 2
            const cy = height / 2
            const top = -Math.PI / 2
            const showBolt = ring.charging && !ring.empty

            // Room for the bolt at 12 o'clock: the ring is cut open there.
            const bh = lw * 2.6
            const bw = bh * 0.9
            const cut = showBolt ? (bw * 0.5 + lw * 0.75) / r : 0
            const a0 = top + cut
            const a1 = top + Math.PI * 2 - cut

            ctx.lineWidth = lw
            ctx.lineCap = "round"

            ctx.strokeStyle = ring.trackColor
            ctx.beginPath()
            ctx.arc(cx, cy, r, a0, a1, false)
            ctx.stroke()

            if (!ring.empty && ring.level > 0) {
                ctx.strokeStyle = ring.arcColor
                ctx.beginPath()
                ctx.arc(cx, cy, r, a0, a0 + (a1 - a0) * Math.min(1, ring.level), false)
                ctx.stroke()
            }

            if (showBolt) {
                const bx = cx - bw / 2
                const by = cy - r - bh / 2
                const P = [[0.556, 0], [0, 0.6], [0.5, 0.6], [0.444, 1.0], [1, 0.4], [0.5, 0.4]]
                ctx.fillStyle = ring.arcColor
                ctx.strokeStyle = ring.arcColor
                ctx.lineWidth = bh * 0.09
                ctx.lineJoin = "round"
                ctx.beginPath()
                for (let i = 0; i < P.length; i++) {
                    const px = bx + P[i][0] * bw
                    const py = by + P[i][1] * bh
                    if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
                }
                ctx.closePath()
                ctx.fill()
                ctx.stroke()
            }
        }
    }

    DeviceGlyph {
        anchors.centerIn: parent
        width: Math.min(ring.width, ring.height) * ring.glyphScale
        height: width
        kind: ring.kind
        color: ring.glyphColor
        visible: !ring.empty
    }
}
