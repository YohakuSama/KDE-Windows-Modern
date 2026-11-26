import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    property color shellAccent: Kirigami.Theme.highlightColor
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
        shellAccent: page.shellAccent
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

    PageFooter {
        sourceComponent: page.footer
    }
}
