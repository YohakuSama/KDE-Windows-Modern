// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import "lockMetrics.js" as LockMetrics

StatusIconButton {
    id: button
    property alias iconName: button.icon.name
    Layout.preferredWidth: LockMetrics.statusButtonExtent
    Layout.preferredHeight: LockMetrics.statusButtonExtent
    Layout.alignment: Qt.AlignVCenter
    focusPolicy: Qt.TabFocus
}
