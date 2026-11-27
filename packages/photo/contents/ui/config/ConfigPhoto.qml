// Picture / GIF settings. SliderField.qml is symlinked from 1-common/config.

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.SimpleKCM {
    id: page

    property alias cfg_imagePath: pathField.text
    property alias cfg_fillMode: fillCombo.currentIndex
    property alias cfg_imagePaddingPct: paddingField.value
    property alias cfg_imageOpacityPct: opacityField.value
    property alias cfg_showGlass: glassCheck.checked

    Dialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose a picture or GIF")
        nameFilters: [
            i18n("Pictures and GIFs (*.png *.jpg *.jpeg *.gif *.webp *.bmp *.svg)"),
            i18n("All files (*)")
        ]
        onAccepted: pathField.text = selectedFile.toString()
    }

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: i18n("Picture:")
            Layout.fillWidth: true

            QQC2.TextField {
                id: pathField
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 12
                placeholderText: i18n("Path or address of a picture or GIF")
                selectByMouse: true
            }
            QQC2.Button {
                icon.name: "document-open"
                text: i18n("Browse…")
                onClicked: fileDialog.open()
            }
            QQC2.Button {
                icon.name: "edit-clear"
                display: QQC2.AbstractButton.IconOnly
                enabled: pathField.text !== ""
                onClicked: pathField.text = ""
                QQC2.ToolTip.text: i18n("Remove the picture")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 28
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("PNG, WebP and GIF files can have transparent areas: the glass behind the picture shows through them. GIFs are animated.")
        }

        QQC2.ComboBox {
            id: fillCombo
            Kirigami.FormData.label: i18n("Fit:")
            model: [
                i18n("Fit (show the whole picture)"),
                i18n("Fill (crop to the widget)"),
                i18n("Stretch")
            ]
        }

        SliderField {
            id: paddingField
            Kirigami.FormData.label: i18n("Margin:")
            from: 0; to: 30; stepSize: 1
            format: (v) => i18nc("percentage", "%1%", v)
        }

        SliderField {
            id: opacityField
            Kirigami.FormData.label: i18n("Opacity:")
            from: 10; to: 100; stepSize: 5
            format: (v) => i18nc("percentage", "%1%", v)
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: glassCheck
            Kirigami.FormData.label: i18n("Background:")
            text: i18n("Liquid glass behind the picture")
        }
    }
}
