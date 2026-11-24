/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Start menu configuration UI.
 *   Follows the Start.Next.Menu pattern: FormData.label directly on
 *   controls, not wrapped in Item.
 ***************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
    id: configGeneral

    property string cfg_icon: Plasmoid.configuration.icon
    property bool cfg_useCustomButtonImage: Plasmoid.configuration.useCustomButtonImage
    property string cfg_customButtonImage: Plasmoid.configuration.customButtonImage
    // Keep the persisted 0/2/3 values; legacy 1 maps to centered at panel.
    property int cfg_displayPosition: Plasmoid.configuration.displayPosition
    property alias cfg_showRightColumn: showRightColumn.checked
    property alias cfg_allAppsSortMode: allAppsSortMode.currentIndex
    property alias cfg_menuTranslucency: menuTranslucency.currentIndex
    property alias cfg_startMenuSize: startMenuSize.currentIndex
    property alias cfg_showPinnedSection: pinnedSection.checked
    property alias cfg_showRecentSection: recentSection.checked
    property alias cfg_showAllSection: allSection.checked
    property alias cfg_hideAccountIdentity: hideAccountIdentity.checked
    property alias cfg_allAppsViewMode: allAppsViewMode.currentIndex
    property alias cfg_showRecentApps: recentApps.checked
    property alias cfg_showRecentDocs: recentDocs.checked

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        // ── Icon ───────────────────────────────────────────────────────
        Button {
            id: iconButton

            Kirigami.FormData.label: i18n("Icon:")

            implicitWidth: previewFrame.width + Kirigami.Units.smallSpacing * 2
            implicitHeight: previewFrame.height + Kirigami.Units.smallSpacing * 2

            checkable: true
            checked: false

            onPressed: iconMenu.opened ? iconMenu.close() : iconMenu.open()

            Kirigami.Icon {
                id: previewFrame
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.large
                height: width
                source: configGeneral.cfg_useCustomButtonImage
                        ? configGeneral.cfg_customButtonImage
                        : configGeneral.cfg_icon
            }

            Menu {
                id: iconMenu
                y: parent.height

                onClosed: iconButton.checked = false

                MenuItem {
                    text: i18nc("@item:inmenu Open icon chooser dialog", "Choose…")
                    icon.name: "document-open-folder"
                    onClicked: iconDialog.open()
                }
                MenuItem {
                    text: i18nc("@item:inmenu Reset icon to default", "Clear Icon")
                    icon.name: "edit-clear"
                    onClicked: {
                        configGeneral.cfg_icon = "start-here"
                        configGeneral.cfg_useCustomButtonImage = false
                    }
                }
            }

            KIconThemes.IconDialog {
                id: iconDialog

                function setCustomButtonImage(image) {
                    configGeneral.cfg_customButtonImage = image
                        || configGeneral.cfg_icon
                        || "start-here"
                    configGeneral.cfg_useCustomButtonImage = true
                }

                onIconNameChanged: setCustomButtonImage(iconName)
            }
        }

        // ── Section separator ──────────────────────────────────────────
        Item {
            Kirigami.FormData.isSection: true
        }

        // ── Display position ───────────────────────────────────────────
        ComboBox {
            Kirigami.FormData.label: i18n("Menu position")
            id: displayPosition
            model: [
                i18n("Follow Start button"),
                i18n("Center at panel"),
                i18n("Left at panel"),
            ]
            currentIndex: configGeneral.cfg_displayPosition === 3 ? 2
                        : configGeneral.cfg_displayPosition === 1
                          || configGeneral.cfg_displayPosition === 2 ? 1 : 0
            onActivated: function(index) {
                configGeneral.cfg_displayPosition = index === 2 ? 3 : index === 1 ? 2 : 0;
            }
        }

        ComboBox {
            id: startMenuSize
            Kirigami.FormData.label: i18n("Start menu size")
            model: [i18n("Automatic"), i18n("Small"), i18n("Large")]
        }

        CheckBox {
            id: pinnedSection
            Kirigami.FormData.label: i18n("Show pinned section")
        }
        CheckBox {
            id: recentSection
            Kirigami.FormData.label: i18n("Show recent section")
        }
        CheckBox {
            id: allSection
            Kirigami.FormData.label: i18n("Show all apps section")
        }
        ComboBox {
            id: allAppsViewMode
            Kirigami.FormData.label: i18n("All apps view")
            model: [i18n("List"), i18n("Grid"), i18n("Category")]
            enabled: allSection.checked
        }
        CheckBox {
            id: hideAccountIdentity
            Kirigami.FormData.label: i18n("Hide your name and profile picture on Start")
        }

        // ── Show places column ─────────────────────────────────────────
        CheckBox {
            id: showRightColumn
            Kirigami.FormData.label: i18n("Show folder shortcuts in footer")
        }

        CheckBox {
            id: recentApps
            enabled: recentSection.checked
            Kirigami.FormData.label: i18n("Show recent applications")
        }
        CheckBox {
            id: recentDocs
            enabled: recentSection.checked
            Kirigami.FormData.label: i18n("Show recent files")
        }

        // ── All apps sort ──────────────────────────────────────────────
        ComboBox {
            Kirigami.FormData.label: i18n("All apps sort")
            id: allAppsSortMode
            model: [
                i18n("Name (A-Z)"),
                i18n("Name (Z-A)"),
                i18n("Newest first"),
                i18n("Oldest first"),
                i18n("Category")
            ]
        }

        // ── Menu translucency ──────────────────────────────────────────
        ComboBox {
            Kirigami.FormData.label: i18n("Menu translucency")
            id: menuTranslucency
            model: [
                i18n("Follow desktop theme"),
                i18n("Translucent"),
                i18n("Opaque")
            ]
        }
    }
}
