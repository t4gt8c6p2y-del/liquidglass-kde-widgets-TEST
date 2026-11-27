import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "components"

// Picture / GIF frame. The liquid glass is the background; the picture is drawn
// on top of it, so any transparent part of a PNG / WebP / GIF lets the glass
// (and, through it, the desktop) show through.
PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    WidgetActions { id: commonActions }

    Plasmoid.contextualActions: commonActions.list
    preferredRepresentation: fullRepresentation

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        appearance: plasmoid.configuration.appearance
    }

    readonly property string _rawPath: (plasmoid.configuration.imagePath || "").trim()

    // A typed path ("/home/me/pic.gif") becomes a file:// address; addresses
    // that already have a scheme (file://, https://) are kept as they are.
    readonly property url imageSource: {
        const p = _rawPath
        if (p === "") return ""
        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(p)) return p
        return "file://" + encodeURI(p)
    }

    // GIFs (and other animated formats) go through AnimatedImage.
    readonly property bool isAnimated: /\.(gif|webp|apng|mng)(\?.*)?$/i.test(_rawPath)

    function _fillMode() {
        switch (plasmoid.configuration.fillMode) {
        case 1: return Image.PreserveAspectCrop
        case 2: return Image.Stretch
        default: return Image.PreserveAspectFit
        }
    }

    fullRepresentation: Item {
        id: full

        Layout.preferredWidth:  width  > 0 ? width  : 240
        Layout.preferredHeight: height > 0 ? height : 240
        Layout.minimumWidth: 120
        Layout.minimumHeight: 120

        readonly property real _margin: Math.round(Math.min(width, height)
                                                   * plasmoid.configuration.imagePaddingPct / 100)
        readonly property bool _loadFailed: root._rawPath !== ""
            && (root.isAnimated ? animImage.status === Image.Error
                                : staticImage.status === Image.Error)

        LiquidGlass {
            id: glass
            anchors.fill: parent
            visible: plasmoid.configuration.showGlass
            radius: plasmoid.configuration.cornerRadius
            roundness: plasmoid.configuration.roundnessX10 / 10
            refractThickness: plasmoid.configuration.refractThickness
            refractIOR: plasmoid.configuration.refractIORx100 / 100
            refractScale: plasmoid.configuration.refractScale
            tint: colors.glassTint
            tintAlpha: plasmoid.configuration.tintAlphaPct / 100
            chromaStrength: plasmoid.configuration.chromaStrengthPct / 100
            specStrength: plasmoid.configuration.specStrengthPct / 100
            blurRadius: plasmoid.configuration.blurRadiusPx
            blurAlgorithm: plasmoid.configuration.blurAlgorithm
            realtimeRefraction: plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            solidMode: colors.isSolid
            solidColor: colors.solidBackground
        }

        // The picture, clipped to rounded corners that follow the glass shape.
        Item {
            id: frame
            anchors.fill: parent
            anchors.margins: full._margin
            visible: root._rawPath !== ""
            opacity: plasmoid.configuration.imageOpacityPct / 100

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: frameMask
            }

            Image {
                id: staticImage
                anchors.fill: parent
                visible: !root.isAnimated
                source: root.isAnimated ? "" : root.imageSource
                fillMode: root._fillMode()
                asynchronous: true
                smooth: true
                mipmap: true
            }

            AnimatedImage {
                id: animImage
                anchors.fill: parent
                visible: root.isAnimated
                source: root.isAnimated ? root.imageSource : ""
                fillMode: root._fillMode()
                // Stop decoding frames while the widget is hidden.
                playing: root.isAnimated && full.visible
                smooth: true
            }
        }

        // Mask shape for the picture (same size as the picture area).
        Item {
            id: frameMask
            visible: false
            layer.enabled: true
            x: frame.x
            y: frame.y
            width: frame.width
            height: frame.height

            Rectangle {
                anchors.fill: parent
                color: "black"
                radius: Math.max(0, Math.min(plasmoid.configuration.cornerRadius - full._margin,
                                             Math.min(width, height) / 2))
            }
        }

        // Empty / error state.
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width * 0.8
            spacing: Kirigami.Units.smallSpacing
            visible: root._rawPath === "" || full._loadFailed

            // Sized from the widget so it scales with resizing.
            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.round(Math.min(full.width, full.height) * 0.2)
                Layout.preferredHeight: Layout.preferredWidth
                source: full._loadFailed ? "dialog-warning" : "folder-pictures"
                color: colors.foreground
                isMask: true
                opacity: 0.45
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: colors.foreground
                opacity: 0.45
                font.pixelSize: Math.max(11, Math.round(Math.min(full.width, full.height) * 0.07))
                text: full._loadFailed
                      ? i18n("This picture couldn't be loaded.")
                      : i18n("Click here to choose a picture or GIF.")
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root._rawPath === "" || full._loadFailed
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                const action = Plasmoid.internalAction("configure")
                if (action) action.trigger()
            }
        }
    }
}
