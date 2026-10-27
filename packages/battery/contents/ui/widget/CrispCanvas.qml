import QtQuick

// A Canvas that stays sharp on high-DPI and fractionally scaled screens.
//
// A plain Canvas is rasterised at the item's logical size and then stretched
// to the screen, which looks soft/pixelated. This one renders at twice the
// device resolution and shows it scaled back down, so edges are properly
// anti-aliased. Draw in logical coordinates (0..width, 0..height) in the
// `paint` handler:  onPaint: (ctx) => { ... }
Item {
    id: root

    signal paint(var ctx)

    readonly property real k: Math.max(2, 2 * Screen.devicePixelRatio)

    function requestPaint() { canvas.requestPaint() }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onKChanged: requestPaint()

    Canvas {
        id: canvas
        width: Math.max(1, Math.ceil(root.width * root.k))
        height: Math.max(1, Math.ceil(root.height * root.k))
        scale: root.width > 0 ? root.width / width : 1
        transformOrigin: Item.TopLeft
        smooth: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.scale(width / Math.max(1, root.width), height / Math.max(1, root.height))
            root.paint(ctx)
        }
    }
}
