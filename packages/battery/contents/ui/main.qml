import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import "components"
import "widget"
import "widget/devices.js" as Devices

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    WidgetActions { id: commonActions }

    PlasmaCore.Action {
        id: refreshAction
        text: i18n("Refresh")
        icon.name: "view-refresh"
        onTriggered: runner.run()
    }

    Plasmoid.contextualActions: [refreshAction].concat(commonActions.list)

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        appearance: plasmoid.configuration.appearance
    }

    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("../fonts/sf_pro_display_regular.otf")
    }

    // ── Data ──────────────────────────────────────────────────────────────
    // Parsed output of scripts/devices.sh: the computer's battery, the
    // peripherals / phones that report one, and the power profile.
    property var info: Devices.parse("")

    // `sh <file>` so the script needs no executable bit.
    readonly property string _scriptPath:
        decodeURIComponent(Qt.resolvedUrl("scripts/devices.sh").toString().replace(/^file:\/\//, ""))
    readonly property string _command: "sh '" + _scriptPath.replace(/'/g, "'\\''") + "'"

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            root._apply(data["stdout"])
        }
        function run() { connectSource(root._command) }
    }

    function _apply(text) {
        const next = Devices.parse(text)
        // Only touch `info` when something really changed so the rings don't
        // re-evaluate (and re-animate) on every poll.
        if (JSON.stringify(next) !== JSON.stringify(root.info))
            root.info = next
    }

    // Battery levels move slowly; a light poll is plenty (one short script
    // every 30 s, and nothing while the widget is hidden).
    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: runner.run()
    }

    // ── View ──────────────────────────────────────────────────────────────
    fullRepresentation: Item {
        id: full
        Layout.preferredWidth:  full.width  > 0 ? full.width  : 300
        Layout.preferredHeight: full.height > 0 ? full.height : 300
        Layout.minimumWidth: 160
        Layout.minimumHeight: 160

        // Same switch as the other widgets: wide from 2:1.
        readonly property bool isWide: full.width >= full.height * 2
        // Square content area (centered) used by the two square layouts.
        readonly property real side: Math.min(full.width, full.height)
        readonly property real ox: (full.width - side) / 2
        readonly property real oy: (full.height - side) / 2

        // Computer + at most 3 other devices.
        readonly property int otherCount: Math.min(3, root.info.others.length)
        // single: computer only (big %)   grid: 2x2 rings   wide: 4 in a row
        readonly property string mode: isWide ? "wide" : (otherCount > 0 ? "grid" : "single")

        function slotData(i) {
            if (i === 0) {
                return {
                    kind: root.info.hasBattery ? "laptop" : "desktop",
                    hasValue: root.info.hasBattery,
                    // A computer without battery shows a full ring.
                    percent: root.info.hasBattery ? root.info.percent : 100,
                    saver: root.info.hasBattery && root.info.powerSave
                }
            }
            const o = i - 1 < otherCount ? root.info.others[i - 1] : null
            if (!o) return null
            return { kind: o.kind, hasValue: true, percent: o.percent, saver: false }
        }

        readonly property var slots: {
            const arr = []
            for (let i = 0; i < 4; i++) arr.push(slotData(i))
            return arr
        }

        // Wide layout metrics (everything derives from the height).
        readonly property real wideD: full.height * 0.40
        readonly property real wideMargin: full.height * 0.115
        readonly property real widePitch: Math.min(full.height * 0.62,
                                                   (full.width - 2 * wideMargin - wideD) / 3)
        readonly property real wideX0: (full.width - wideD - 3 * widePitch) / 2

        function ringRect(i) {
            const s = full.side
            if (mode === "wide") {
                return { x: wideX0 + i * widePitch, y: full.height * 0.177, d: wideD }
            }
            if (mode === "grid") {
                const m = s * 0.09
                const d = s * 0.36
                const step = s - 2 * m - d      // distance between ring origins
                return {
                    x: full.ox + m + (i % 2) * step,
                    y: full.oy + m + Math.floor(i / 2) * step,
                    d: d
                }
            }
            // single
            return { x: full.ox + s * 0.075, y: full.oy + s * 0.07, d: s * 0.40 }
        }

        // Centre line of the "NN %" label, its size and room, per mode.
        function textRect(i) {
            const s = full.side
            if (mode === "wide") {
                const r = ringRect(i)
                return {
                    show: slots[i] !== null,
                    x: r.x + full.height * 0.01,
                    cy: full.height * 0.758,
                    px: full.height * 0.15,
                    w: widePitch * 0.96
                }
            }
            if (mode === "single") {
                return {
                    show: i === 0,
                    x: full.ox + s * 0.075,
                    cy: full.oy + s * 0.80,
                    px: s * 0.26,
                    w: s * 0.86
                }
            }
            return { show: false, x: 0, cy: 0, px: 10, w: 10 }
        }

        LiquidGlass {
            id: glass
            anchors.fill: parent
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

        // ── Rings ─────────────────────────────────────────────────────────
        Repeater {
            model: 4

            BatteryRing {
                id: ringItem
                required property int index

                readonly property var rect: full.ringRect(index)
                readonly property var dev: full.slots[index]

                x: rect.x
                y: rect.y
                width: rect.d
                height: rect.d

                // Slot 0 is always the computer. In the grid and wide layouts free
                // slots stay as empty rings, like the iOS widget.
                opacity: (index === 0 || dev !== null || full.mode !== "single") ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                empty: dev === null
                level: dev !== null ? dev.percent / 100 : 0
                kind: dev !== null ? dev.kind : "generic"
                arcColor: (dev !== null && dev.saver) ? colors.batteryRingSaver : colors.batteryRing
                trackColor: colors.batteryTrack
                glyphColor: colors.foreground
            }
        }

        // ── "NN %" labels ─────────────────────────────────────────────────
        Repeater {
            model: 4

            Text {
                id: label
                required property int index

                readonly property var rect: full.textRect(index)
                readonly property var dev: full.slots[index]

                x: rect.x
                y: rect.cy - height / 2
                width: rect.w
                opacity: rect.show ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                text: (dev !== null && dev.hasValue)
                      ? i18nc("battery percentage", "%1 %", dev.percent)
                      : "–"
                color: colors.foreground
                font.family: sfRegular.name
                font.pixelSize: rect.px
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 8
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideNone
                wrapMode: Text.NoWrap
            }
        }
    }
}
