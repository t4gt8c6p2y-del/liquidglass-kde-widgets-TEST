// Battery variant of the shared appearance page (GlassAppearancePage.qml):
// adds the main ring color and the power-saving color options to the Style tab.

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
    property alias cfg_saverColorEnabled: saverCheck.checked
    property string cfg_saverColor: "#FFCC00"
    property string cfg_saverColorDefault: "#FFCC00"

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
        },
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Power saving")
        },
        QQC2.CheckBox {
            id: saverCheck
            Kirigami.FormData.label: i18n("Ring color:")
            text: i18n("Change color when power saving is on")
        },
        RowLayout {
            Kirigami.FormData.label: i18n("Power saving color:")
            enabled: saverCheck.checked
            spacing: Kirigami.Units.smallSpacing

            KQuickControls.ColorButton {
                id: saverColorButton
                showAlphaChannel: false
                Component.onCompleted: color = page.cfg_saverColor
                onColorChanged: page.cfg_saverColor = color.toString()
            }
            QQC2.Button {
                text: i18n("Reset")
                icon.name: "edit-undo"
                onClicked: saverColorButton.color = page.cfg_saverColorDefault
            }
        }
    ]

    serializeExtras: (o) => {
        o.rc = page.cfg_ringColor
        o.se = saverCheck.checked
        o.sc = page.cfg_saverColor
    }
    deserializeExtras: (o) => {
        if (o.rc !== undefined) ringColorButton.color = o.rc
        if (o.se !== undefined) saverCheck.checked = o.se
        if (o.sc !== undefined) saverColorButton.color = o.sc
    }
}
