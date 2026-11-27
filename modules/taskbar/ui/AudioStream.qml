/*
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

Item {
    id: audioStreamIconBox

    required property Item taskItem
    required property Item taskIconBox
    required property Item taskTile
    readonly property QtObject layoutInputs: taskItem.layoutInputs

    width: Math.round(Math.min(Math.min(audioStreamIconBox.taskIconBox.width, audioStreamIconBox.taskIconBox.height) * 0.4, Kirigami.Units.iconSizes.smallMedium))
    height: width
    anchors {
        top: audioStreamIconBox.taskTile.top
        right: audioStreamIconBox.taskTile.right
        rightMargin: audioStreamIconBox.layoutInputs.frameRight
        topMargin: Math.round(audioStreamIconBox.layoutInputs.frameTop * indicatorScale)
    }

    readonly property real indicatorScale: 1.2

    activeFocusOnTab: true

    // Using States rather than a simple Behavior we can apply different transitions,
    // which allows us to delay showing the icon but hide it instantly still.
    states: [
        State {
            name: "playing"
            when: audioStreamIconBox.taskItem.playingAudio && !audioStreamIconBox.taskItem.muted
            PropertyChanges {
                audioStreamIconBox.opacity: 1
                audioStreamIcon.source: "audio-volume-high-symbolic" + (Application.layoutDirection === Qt.RightToLeft ? "-rtl" : "")
            }
        },
        State {
            name: "muted"
            when: audioStreamIconBox.taskItem.muted
            PropertyChanges {
                audioStreamIconBox.opacity: 1
                audioStreamIcon.source: "audio-volume-muted-symbolic" + (Application.layoutDirection === Qt.RightToLeft ? "-rtl" : "")
            }
        }
    ]

    transitions: [
        Transition {
             from: ""
             to: "playing"
             SequentialAnimation {
                 // Delay showing the play indicator so we don't flash it for brief sounds.
                 PauseAnimation {
                     duration: !audioStreamIconBox.taskItem.delayAudioStreamIndicator || audioStreamIconBox.taskItem.inPopup ? 0 : 2000
                 }
                 NumberAnimation {
                     property: "opacity"
                     duration: Kirigami.Units.longDuration
                 }
             }
        },
        Transition {
             from: ""
             to: "muted"
             SequentialAnimation {
                 NumberAnimation {
                     property: "opacity"
                     duration: Kirigami.Units.longDuration
                 }
             }
        },
        Transition {
             to: ""
             NumberAnimation {
                 property: "opacity"
                 duration: Kirigami.Units.longDuration
             }
        }
    ]

    opacity: 0
    visible: opacity > 0

    Keys.onReturnPressed: event => audioStreamIconBox.taskItem.toggleMuted()
    Keys.onEnterPressed: event => Keys.returnPressed(event);
    Keys.onSpacePressed: event => Keys.returnPressed(event);

    Accessible.checkable: true
    Accessible.checked: audioStreamIconBox.taskItem.muted
    Accessible.name: audioStreamIconBox.taskItem.muted ? i18nc("@action:button", "Unmute") : i18nc("@action:button", "Mute")
    Accessible.description: audioStreamIconBox.taskItem.muted ? i18nc("@info:tooltip %1 is the window title", "Unmute %1", audioStreamIconBox.taskItem.model.display) : i18nc("@info:tooltip %1 is the window title", "Mute %1", audioStreamIconBox.taskItem.model.display)
    Accessible.role: Accessible.Button

    HoverHandler {
        id: hoverHandler
        enabled: Plasmoid.configuration.interactiveMute
    }

    TapHandler {
        id: tapHandler
        gesturePolicy: TapHandler.ReleaseWithinBounds // Exclusive grab
        enabled: Plasmoid.configuration.interactiveMute
        onTapped: (eventPoint, button) => audioStreamIconBox.taskItem.toggleMuted()
    }

    PlasmaExtras.Highlight {
        anchors.fill: audioStreamIcon
        hovered: hoverHandler.hovered || parent.activeFocus
        pressed: tapHandler.pressed
    }

    Kirigami.Icon {
        id: audioStreamIcon

        // Need audio indicator twice, to keep iconBox in the center.
        readonly property real requiredSpace: Math.min(audioStreamIconBox.taskIconBox.width, audioStreamIconBox.taskIconBox.height)
            + Math.min(Math.min(audioStreamIconBox.taskIconBox.width, audioStreamIconBox.taskIconBox.height), Kirigami.Units.iconSizes.smallMedium) * 2

        source: "audio-volume-high-symbolic" + (Application.layoutDirection === Qt.RightToLeft ? "-rtl" : "")
        selected: tapHandler.pressed

        height: Math.round(Math.min(parent.height * audioStreamIconBox.indicatorScale, Kirigami.Units.iconSizes.smallMedium))
        width: height

        anchors {
            verticalCenter: parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
        }

        states: [
            State {
                name: "verticalIconsOnly"
                when: audioStreamIconBox.layoutInputs.vertical && audioStreamIconBox.taskTile.width < audioStreamIcon.requiredSpace

                PropertyChanges {
                    audioStreamIconBox.anchors.rightMargin: Math.round(audioStreamIconBox.layoutInputs.frameRight * indicatorScale)
                }
            },

            State {
                name: "horizontal"
                when: audioStreamIconBox.taskTile.width > audioStreamIcon.requiredSpace

                AnchorChanges {
                    target: audioStreamIconBox

                    anchors.top: undefined
                    anchors.verticalCenter: audioStreamIconBox.taskTile.verticalCenter
                }

                PropertyChanges {
                    audioStreamIconBox.width: Kirigami.Units.iconSizes.roundedIconSize(Math.min(Math.min(audioStreamIconBox.taskIconBox.width, audioStreamIconBox.taskIconBox.height), Kirigami.Units.iconSizes.smallMedium))
                    audioStreamIcon.height: audioStreamIcon.parent.height
                    audioStreamIcon.width: audioStreamIcon.parent.width
                }
            },

            State {
                name: "vertical"
                when: audioStreamIconBox.taskTile.height > audioStreamIcon.requiredSpace

                AnchorChanges {
                    target: audioStreamIconBox

                    anchors.right: undefined
                    anchors.horizontalCenter: audioStreamIconBox.taskTile.horizontalCenter
                }

                PropertyChanges {
                    audioStreamIconBox.anchors.topMargin: audioStreamIconBox.layoutInputs.frameTop
                    audioStreamIconBox.width: Kirigami.Units.iconSizes.roundedIconSize(Math.min(Math.min(audioStreamIconBox.taskIconBox.width, audioStreamIconBox.taskIconBox.height), Kirigami.Units.iconSizes.smallMedium))
                    audioStreamIcon.height: audioStreamIcon.parent.height
                    audioStreamIcon.width: audioStreamIcon.parent.width
                }
            }
        ]
    }
}
