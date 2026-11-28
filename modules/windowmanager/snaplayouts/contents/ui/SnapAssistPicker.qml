// SPDX-License-Identifier: GPL-3.0-or-later
// Snap Assist: after snapping a window into a layout zone, offer eligible open
// windows on the current desktop to fill the remaining open zone(s) in order.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

import "layouts.js" as Layouts

PlasmaCore.Window {
    id: assist

    signal windowChosen(var win)
    signal dismissed()

    property rect zoneRect: Qt.rect(0, 0, 1, 1)
    property var candidates: []
    property string closeText: qsTr("Close")

    readonly property int contentInset: 8
    readonly property int topBarHeight: 26
    readonly property int availableZoneWidth: Math.max(1,
        zoneRect.width - Layouts.assistOuterMargin * 2 - leftPadding - rightPadding)
    readonly property int availableZoneHeight: Math.max(1,
        zoneRect.height - Layouts.assistOuterMargin * 2 - topPadding - bottomPadding)
    readonly property int cardColumns: Math.max(1, Math.min(
        Math.max(1, candidates.length),
        availableZoneWidth >= 540 ? 3 : availableZoneWidth >= 300 ? 2 : 1))
    readonly property int cardWidth: Math.max(96, Math.min(220,
        Math.floor((availableZoneWidth - contentInset * 2 - (cardColumns - 1) * Layouts.assistCardGap) / cardColumns)))
    readonly property int cardHeight: Math.max(76, Math.min(156, Math.round(cardWidth * 0.68)))
    readonly property int rowCount: Math.max(1, Math.ceil(Math.max(1, candidates.length) / cardColumns))
    readonly property int gridWidth: cardColumns * cardWidth + (cardColumns - 1) * Layouts.assistCardGap
    readonly property int gridHeight: rowCount * cardHeight + (rowCount - 1) * Layouts.assistCardGap
    readonly property int viewportHeight: Math.max(1, Math.min(gridHeight,
        Math.max(1, availableZoneHeight - topBarHeight - contentInset * 2 - 4)))

    visible: false
    flags: Qt.X11BypassWindowManagerHint | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    width: Math.min(zoneRect.width, gridWidth + contentInset * 2 + leftPadding + rightPadding)
    height: Math.min(zoneRect.height, topBarHeight + viewportHeight + contentInset * 2 + 4 + topPadding + bottomPadding)

    function reposition() {
        if (zoneRect.width <= 0 || zoneRect.height <= 0) {
            return;
        }
        const centeredX = Math.round(zoneRect.x + (zoneRect.width - width) / 2);
        const centeredY = Math.round(zoneRect.y + (zoneRect.height - height) / 2);
        x = Math.max(zoneRect.x, Math.min(centeredX, zoneRect.x + zoneRect.width - width));
        y = Math.max(zoneRect.y, Math.min(centeredY, zoneRect.y + zoneRect.height - height));
    }

    function showForZone(rect, windowList) {
        if (!rect || rect.width < 140 || rect.height < 110 || !windowList || windowList.length === 0) {
            hideAssist();
            return false;
        }
        zoneRect = rect;
        candidates = windowList;
        if (width > rect.width || height > rect.height) {
            hideAssist();
            return false;
        }
        reposition();
        visible = true;
        reposition();
        return true;
    }

    function hideAssist() {
        visible = false;
        candidates = [];
    }

    onWidthChanged: if (visible) reposition()
    onHeightChanged: if (visible) reposition()

    mainItem: Item {
        id: container
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        width: Math.max(1, assist.width - assist.leftPadding - assist.rightPadding)
        height: Math.max(1, assist.height - assist.topPadding - assist.bottomPadding)

        MouseArea {
            anchors.fill: parent
            onClicked: assist.dismissed()
        }

        Item {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Math.round(assist.contentInset / 2)
            anchors.leftMargin: assist.contentInset
            anchors.rightMargin: assist.contentInset
            height: assist.topBarHeight

            Rectangle {
                id: dismissButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: Layouts.assistPreviewRadius
                color: dismissMouse.containsPress ? Qt.darker("#C42B1C", 1.15)
                     : dismissMouse.containsMouse ? "#C42B1C" : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Kirigami.Units.shortDuration > 0 ? 90 : 0 }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    roundToIconSize: false
                    source: "window-close-symbolic"
                    color: dismissMouse.containsMouse ? "#FFFFFF" : Kirigami.Theme.textColor
                    isMask: true
                }

                MouseArea {
                    id: dismissMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: assist.dismissed()
                }

                Accessible.role: Accessible.Button
                Accessible.name: assist.closeText
                Accessible.onPressAction: assist.dismissed()
            }
        }

        Flickable {
            id: flick
            anchors.top: topBar.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - assist.contentInset * 2, assist.gridWidth)
            height: assist.viewportHeight
            contentWidth: grid.width
            contentHeight: grid.height
            interactive: contentHeight > height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Grid {
                id: grid
                columns: assist.cardColumns
                spacing: Layouts.assistCardGap

                Repeater {
                    model: assist.candidates.length

                    Item {
                        id: cardItem
                        required property int index
                        readonly property var win: index < assist.candidates.length ? assist.candidates[index] : null
                        readonly property int innerWidth: Math.max(1, width - Layouts.assistCardPadding * 2)
                        readonly property int thumbHeight: Math.max(1, height - Layouts.assistCardPadding * 2 - Layouts.assistHeaderHeight)

                        width: assist.cardWidth
                        height: assist.cardHeight

                        Accessible.role: Accessible.Button
                        Accessible.name: win && win.caption ? String(win.caption) : ""
                        Accessible.onPressAction: if (win) assist.windowChosen(win)

                        HoverHandler {
                            id: cardHover
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Layouts.assistCardRadius
                            color: cardMouse.containsPress ? Qt.alpha(Kirigami.Theme.textColor, 0.12)
                                 : cardHover.hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.08)
                                 : Qt.alpha(Kirigami.Theme.textColor, 0.04)
                            border.width: Layouts.cellBorderWidth
                            border.color: cardHover.hovered
                                ? Kirigami.Theme.highlightColor
                                : Qt.alpha(Kirigami.Theme.textColor, 0.16)

                            Behavior on color {
                                ColorAnimation { duration: Kirigami.Units.shortDuration > 0 ? 90 : 0 }
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: Kirigami.Units.shortDuration > 0 ? 90 : 0 }
                            }
                        }

                        Item {
                            id: cardHeader
                            x: Layouts.assistCardPadding
                            y: Layouts.assistCardPadding
                            width: cardItem.innerWidth
                            height: Layouts.assistHeaderHeight

                            Kirigami.Icon {
                                id: appIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                roundToIconSize: false
                                source: cardItem.win ? cardItem.win.icon : ""
                            }

                            PlasmaComponents3.Label {
                                anchors.left: appIcon.right
                                anchors.leftMargin: 6
                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: cardItem.win && cardItem.win.caption ? String(cardItem.win.caption) : ""
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                color: Kirigami.Theme.textColor
                            }
                        }

                        Item {
                            x: Layouts.assistCardPadding
                            y: Layouts.assistCardPadding + Layouts.assistHeaderHeight
                            width: cardItem.innerWidth
                            height: cardItem.thumbHeight

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Math.min(32, parent.width, parent.height)
                                height: width
                                roundToIconSize: false
                                source: cardItem.win ? cardItem.win.icon : ""
                            }

                            KWin.WindowThumbnail {
                                anchors.fill: parent
                                wId: cardItem.win ? cardItem.win.internalId : ""
                                layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: thumbMask
                                    maskThresholdMin: 0.5
                                    maskSpreadAtMin: 1.0
                                }
                            }

                            Rectangle {
                                id: thumbMask
                                anchors.fill: parent
                                radius: Layouts.assistPreviewRadius
                                visible: false
                                layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            onClicked: if (cardItem.win) assist.windowChosen(cardItem.win)
                        }
                    }
                }
            }
        }
    }
}
