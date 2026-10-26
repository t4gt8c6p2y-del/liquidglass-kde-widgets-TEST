import QtQuick

// A battery ring like the iOS Batteries widget: a faint full track, a rounded
// arc starting at 12 o'clock and running clockwise, and the device icon in the
// middle. With `empty: true` only the track is drawn (free slot in the wide
// layout).
Item {
    id: ring

    property real level: 0            // 0..1, animated
    property bool empty: false
    property string kind: "generic"
    property color arcColor: "#34C759"
    property color trackColor: Qt.rgba(1, 1, 1, 0.2)
    property color glyphColor: "#ffffff"

    // Ring thickness relative to its diameter.
    readonly property real thickness: 0.085
    // Icon box relative to the ring diameter.
    readonly property real glyphScale: 0.42

    Behavior on level { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    // Canvas doesn't repaint on bound property changes by itself.
    onLevelChanged: arc.requestPaint()
    onArcColorChanged: arc.requestPaint()
    onTrackColorChanged: arc.requestPaint()
    onEmptyChanged: arc.requestPaint()

    Canvas {
        id: arc
        anchors.fill: parent

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const d = Math.min(width, height)
            if (d <= 0) return

            const lw = d * ring.thickness
            const r = (d - lw) / 2
            const cx = width / 2
            const cy = height / 2

            ctx.lineWidth = lw
            ctx.lineCap = "round"

            ctx.strokeStyle = ring.trackColor
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.stroke()

            if (!ring.empty && ring.level > 0) {
                const start = -Math.PI / 2
                ctx.strokeStyle = ring.arcColor
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + Math.PI * 2 * Math.min(1, ring.level), false)
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
