/*
    SPDX-FileCopyrightText: 2026 Jeysef <jeysef@users.noreply.github.com>
    SPDX-License-Identifier: GPL-3.0-or-later

    Windows 11 taskbar Search display modes.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configGeneral
    property int cfg_searchMode

    // i18n() is put into the context by Plasma, where qmllint cannot see it.
    // qmllint disable unqualified
    Kirigami.FormLayout {
        ButtonGroup { id: modeGroup }

        RadioButton {
            Kirigami.FormData.label: i18nc("@label:group", "Show search as:")
            text: i18nc("@option:radio", "Search box")
            ButtonGroup.group: modeGroup
            checked: configGeneral.cfg_searchMode === 0
            onToggled: if (checked) configGeneral.cfg_searchMode = 0
        }
        RadioButton {
            text: i18nc("@option:radio", "Search icon and label")
            ButtonGroup.group: modeGroup
            checked: configGeneral.cfg_searchMode === 1
            onToggled: if (checked) configGeneral.cfg_searchMode = 1
        }
        RadioButton {
            text: i18nc("@option:radio", "Search icon only")
            ButtonGroup.group: modeGroup
            checked: configGeneral.cfg_searchMode === 2
            onToggled: if (checked) configGeneral.cfg_searchMode = 2
        }

        Label {
            Layout.fillWidth: true
            text: i18nc("@info", "Vertical panels always show the icon.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.Wrap
        }
    }
    // qmllint enable unqualified
}
