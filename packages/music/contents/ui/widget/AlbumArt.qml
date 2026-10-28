import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: art

    property string artUrl: ""
    property real radius: 12
    property color fallbackColor: "#2c2c2e"
    property color fallbackIconColor: "#ffffff"

    // The rounded-corner mask is rasterised at a higher resolution than the
    // screen and then filtered down, which is what gives smooth (anti-aliased)
    // corners instead of a stair-stepped edge.
    readonly property real _maskScale: 2 * Math.max(1, Screen.devicePixelRatio)

    Image {
        id: coverImage
        anchors.fill: parent
        source: art.artUrl
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        visible: false
        layer.enabled: true
        layer.smooth: true
        cache: false
    }

    Item {
        id: roundMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.samples: 4
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * art._maskScale)),
                                   Math.max(1, Math.ceil(height * art._maskScale)))

        Rectangle {
            anchors.fill: parent
            radius: art.radius
            color: "white"
            antialiasing: true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: art.fallbackColor
        radius: art.radius
        antialiasing: true
        opacity: 0.3
    }

    MultiEffect {
        anchors.fill: parent
        source: coverImage
        maskEnabled: true
        maskSource: roundMask
        visible: art.artUrl !== ""
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: parent.width * 0.35
        height: parent.height * 0.35
        source: "media-optical-audio"
        color: art.fallbackIconColor
        opacity: 0.4
        visible: art.artUrl === ""
    }
}
