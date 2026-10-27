// Battery variant of the shared appearance page (GlassAppearancePage.qml):
// adds the main ring color to the Style tab.

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

GlassAppearancePage {
    id: page

    // ringColor is a String kcfg; bridge it through a string property the
    // ColorButton reads/writes as a #rrggbb hex.
    property string cfg_ringColor: "#34C759"
    property string cfg_ringColorDefault: "#34C759"

    styleExtras: [
        RowLayout {
            Kirigami.FormData.label: i18n("Main color:")
            spacing: Kirigami.Units.smallSpacing

            KQuickControls.ColorButton {
                id: ringColorButton
                showAlphaChannel: false
                // Seed from the stored config once, then act as the source of truth.
                Component.onCompleted: color = page.cfg_ringColor
                onColorChanged: page.cfg_ringColor = color.toString()
            }
            QQC2.Button {
                text: i18n("Reset")
                icon.name: "edit-undo"
                onClicked: ringColorButton.color = page.cfg_ringColorDefault
            }
        }
    ]

    serializeExtras: (o) => {
        o.rc = page.cfg_ringColor
    }
    deserializeExtras: (o) => {
        if (o.rc !== undefined) ringColorButton.color = o.rc
    }
}
