import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    property string title
    property bool showSwitch: false
    property bool switchEnabled: true
    property bool switchChecked: false
    property bool contentFillsHeight: true
    property Component footer: null

    signal back
    signal switchToggled

    spacing: 0

    default property alias content: contentLayout.data

    PageHeader {
        title: page.title
        showSwitch: page.showSwitch
        switchEnabled: page.switchEnabled
        switchChecked: page.switchChecked
        onBack: page.back()
        onSwitchToggled: page.switchToggled()
    }

    ScrollView {
        id: scrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical: FluentScrollBar {}
        Kirigami.WheelHandler {
            target: scrollView
            filterMouseEvents: true
            keyNavigationEnabled: false
            verticalStepSize: 120
        }

        ColumnLayout {
            id: contentLayout
            width: scrollView.availableWidth
            height: page.contentFillsHeight ? Math.max(implicitHeight, scrollView.availableHeight) : implicitHeight
            spacing: 0
        }
    }

    Rectangle {
        visible: page.footer !== null
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, 0.08)
    }

    Loader {
        id: footerLoader
        visible: page.footer !== null
        active: visible
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        sourceComponent: page.footer
    }
}
