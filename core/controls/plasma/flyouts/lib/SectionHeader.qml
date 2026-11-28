import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/trayMetrics.js" as TrayMetrics

PlasmaComponents3.Label {
    Layout.fillWidth: true
    Layout.leftMargin: TrayMetrics.compactRowContentInset
    Layout.rightMargin: TrayMetrics.compactRowContentInset
    Layout.topMargin: 8
    Layout.bottomMargin: 4
    color: Kirigami.Theme.textColor
    font.pixelSize: 11
    font.weight: Font.DemiBold
}
