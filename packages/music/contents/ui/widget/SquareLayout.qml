import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: layout

    required property QtObject colors
    property real cornerRadius: 24
    property real roundness: 7.5
    property string fontFamily: ""
    property string fontFamilyThin: ""
    property string track: ""
    property string artist: ""
    property string albumArt: ""
    property bool isPlaying: false
    property bool canGoPrevious: false
    property bool canGoNext: false
    property bool canPlay: false
    property bool canPause: false
    property real position: 0
    property real length: 0
    property var formatTime: function(us) { return "" }

    signal togglePlaying()
    signal nextTrack()
    signal previousTrack()
    signal seek(real positionUs)

    readonly property real _m: Math.round(Math.min(width, height) * 0.08)
    readonly property real _s: Math.min(width, height)
    readonly property real _bgArtRadius: Math.min(layout.cornerRadius, Math.min(width, height) * 0.22)

    clip: true

    // Supersampling factor for the squircle mask (see bgArtMask below).
    readonly property real _maskScale: 2 * Math.max(1, Screen.devicePixelRatio)

    // Superellipse outline matching the glass shader's SDF:
    //   q = abs(p) - b + r; corner boundary: (qx^n + qy^n)^(1/n) = r
    // parametrically: qx = r*cos(t)^(2/n), qy = r*sin(t)^(2/n)
    function _squirclePath(w, h, cr, rn) {
        var r = Math.min(cr, w / 2, h / 2)
        var n = Math.max(rn, 2.0)
        var steps = 48
        var pts = []
        function cx(t) { return r * Math.pow(Math.abs(Math.cos(t)), 2.0 / n) }
        function cy(t) { return r * Math.pow(Math.abs(Math.sin(t)), 2.0 / n) }
        var i, t

        pts.push(Qt.point(r, 0))
        pts.push(Qt.point(w - r, 0))
        for (i = 1; i <= steps; i++) {            // top-right
            t = (1 - i / steps) * Math.PI / 2
            pts.push(Qt.point(w - r + cx(t), r - cy(t)))
        }
        pts.push(Qt.point(w, h - r))
        for (i = 1; i <= steps; i++) {            // bottom-right
            t = (1 - i / steps) * Math.PI / 2
            pts.push(Qt.point(w - r + cy(t), h - r + cx(t)))
        }
        pts.push(Qt.point(r, h))
        for (i = 1; i <= steps; i++) {            // bottom-left
            t = (1 - i / steps) * Math.PI / 2
            pts.push(Qt.point(r - cx(t), h - r + cy(t)))
        }
        pts.push(Qt.point(0, r))
        for (i = 1; i <= steps; i++) {            // top-left
            t = (1 - i / steps) * Math.PI / 2
            pts.push(Qt.point(r - cy(t), r - cx(t)))
        }
        return pts
    }

    // Album art as full background with gradient fade-out toward bottom
    Item {
        id: bgArtContainer
        anchors.fill: parent
        visible: layout.albumArt !== ""

        Item {
            id: bgArtSource
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true

            Image {
                anchors.fill: parent
                source: layout.albumArt
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0;  color: Qt.rgba(0, 0, 0, 0.35) }
                    GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.45) }
                    GradientStop { position: 0.85; color: Qt.rgba(0, 0, 0, 0.90) }
                    GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.97) }
                }
            }
        }

        Item {
            id: bgArtMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * layout._maskScale)),
                                       Math.max(1, Math.ceil(height * layout._maskScale)))

            Shape {
                anchors.fill: parent
                ShapePath {
                    fillColor: "white"
                    strokeWidth: -1
                    PathPolyline {
                        path: layout._squirclePath(bgArtMask.width, bgArtMask.height,
                                                   layout.cornerRadius, layout.roundness)
                    }
                }
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: bgArtSource
            maskEnabled: true
            maskSource: bgArtMask
            visible: layout.albumArt !== ""
        }
    }

    // Fallback icon when no album art
    Item {
        anchors.fill: parent
        visible: layout.albumArt === ""

        Rectangle {
            anchors.centerIn: parent
            width: layout._s * 0.3
            height: width
            radius: width * 0.15
            color: layout.colors.foreground
            opacity: 0.08
        }
    }

    // Content overlay
    Item {
        id: content
        anchors.fill: parent
        anchors.margins: layout._m

        Column {
            id: infoCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: controls.top
            anchors.bottomMargin: Math.round(layout._s * 0.04)
            spacing: 2

            MarqueeText {
                width: parent.width
                height: Math.round(layout._s * 0.0735) + 4
                text: layout.track || "Not Playing"
                fontSize: Math.max(13, Math.round(layout._s * 0.0683))
                fontWeight: Font.DemiBold
                fontFamily: layout.fontFamily
                textColor: layout.colors.foreground
                horizontalAlignment: Text.AlignHCenter
            }

            MarqueeText {
                width: parent.width
                height: Math.max(13, Math.round(layout._s * 0.0504)) + 4
                text: layout.artist || "—"
                fontSize: Math.max(9, Math.round(layout._s * 0.0494))
                fontWeight: Font.Medium
                fontFamily: layout.fontFamily
                textColor: layout.colors.foreground
                textOpacity: 0.55
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Row {
            id: controls
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(layout._s * 0.08)

            readonly property real _iconSize: Math.max(20, Math.round(layout._s * 0.11))
            readonly property real _rowH: _iconSize * 1.6

            ControlButton {
                iconSource: Qt.resolvedUrl("../icons/previous.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._iconSize
                height: controls._rowH
                opacity: layout.canGoPrevious ? 1.0 : 0.3
                onClicked: layout.previousTrack()
            }

            ControlButton {
                iconSource: layout.isPlaying ? Qt.resolvedUrl("../icons/pause.svg") : Qt.resolvedUrl("../icons/play.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._iconSize
                height: controls._rowH
                opacity: (layout.canPlay || layout.canPause) ? 1.0 : 0.3
                onClicked: layout.togglePlaying()
            }

            ControlButton {
                iconSource: Qt.resolvedUrl("../icons/next.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._iconSize
                height: controls._rowH
                opacity: layout.canGoNext ? 1.0 : 0.3
                onClicked: layout.nextTrack()
            }
        }
    }
}
