/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasmoid
import plasma.applet.org.kde.plasma.icontasks as TaskManagerApplet

DropArea {
    id: dropArea
    signal urlsDropped(var urls)

    required property Item tasksRoot
    readonly property var tasksModel: tasksRoot.tasksModel

    property Item target
    property Item ignoredItem
    property Item hoveredItem
    property bool isGroupDialog: false
    property bool moved: false

    property alias handleWheelEvents: wheelHandler.handleWheelEvents

    //ignore anything that is neither internal to TaskManager or a URL list
    onEntered: event => {
        if (event.formats.indexOf("text/x-plasmoidservicename") >= 0) {
            event.accepted = false;
        }
        if (target.animating) { // Not all targets have an animating property
            target.animating = false;
        }
    }

    onPositionChanged: event => {
        if (target.animating) {
            return;
        }

        let above;
        if (isGroupDialog) {
            above = target.itemAt(event.x, event.y);
        } else {
            above = target.childAt(event.x, event.y);
        }

        if (!above) {
            hoveredItem = null;
            activationTimer.stop();

            return;
        }

        // If we're mixing launcher tasks with other tasks and are moving
        // a (small) launcher task across a non-launcher task, don't allow
        // the latter to be the move target twice in a row for a while, as
        // it will naturally be moved underneath the cursor as result of the
        // initial move, due to being far larger than the launcher delegate.
        // TODO: This restriction (minus the timer, which improves things)
        // has been proven out in the EITM fork, but could be improved later
        // by tracking the cursor movement vector and allowing the drag if
        // the movement direction has reversed, establishing user intent to
        // move back.
        if (!Plasmoid.configuration.separateLaunchers
                && dropArea.tasksRoot.dragSource?.model.IsLauncher
                && !above.model.IsLauncher
                && above === ignoredItem) {
            return;
        } else {
            ignoredItem = null;
        }

        if (tasksModel.sortMode === TaskManager.TasksModel.SortManual && dropArea.tasksRoot.dragSource) {
            // Reject drags between different TaskList instances.
            if (dropArea.tasksRoot.dragSource.parent !== above.parent) {
                return;
            }

            const insertAt = above.index;

            if (dropArea.tasksRoot.dragSource !== above && dropArea.tasksRoot.dragSource.index !== insertAt) {
                if (dropArea.tasksRoot.groupDialog) {
                    tasksModel.move(dropArea.tasksRoot.dragSource.index, insertAt,
                        tasksModel.makeModelIndex(dropArea.tasksRoot.groupDialog.visualParent.index));
                } else {
                    tasksModel.move(dropArea.tasksRoot.dragSource.index, insertAt);
                }

                ignoredItem = above;
                ignoreItemTimer.restart();
            }
        } else if (!dropArea.tasksRoot.dragSource && hoveredItem !== above) {
            hoveredItem = above;
            activationTimer.restart();
        }
    }

    onExited: {
        hoveredItem = null;
        activationTimer.stop();
    }

    onDropped: event => {
        // Reject internal drops.
        if (event.formats.indexOf("application/x-orgkdeplasmataskmanager_taskbuttonitem") >= 0) {
            event.accepted = false;
            return;
        }

        // Reject plasmoid drops.
        if (event.formats.indexOf("text/x-plasmoidservicename") >= 0) {
            event.accepted = false;
            return;
        }

        if (event.hasUrls) {
            urlsDropped(event.urls);
            return;
        }
    }

    Connections {
        target: dropArea.tasksRoot

        function onDragSourceChanged(): void {
            if (!dropArea.tasksRoot.dragSource) {
                dropArea.ignoredItem = null;
                ignoreItemTimer.stop();
            }
        }
    }

    Timer {
        id: ignoreItemTimer

        repeat: false
        interval: 750

        onTriggered: {
            dropArea.ignoredItem = null;
        }
    }

    Timer {
        id: activationTimer

        interval: 250
        repeat: false

        onTriggered: {
            if (!dropArea.hoveredItem) {
                return;
            }
            if (dropArea.hoveredItem.model.IsGroupParent) {
                TaskManagerApplet.TaskTools.createGroupDialog(dropArea.hoveredItem, dropArea.tasksRoot);
            } else if (!dropArea.hoveredItem.model.IsLauncher) {
                tasksModel.requestActivate(dropArea.hoveredItem.modelIndex());
            }
        }
    }

    WheelHandler {
        id: wheelHandler

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        property bool handleWheelEvents: true

        enabled: handleWheelEvents && Plasmoid.configuration.wheelEnabled !== 0

        onWheel: event => {
            // magic number 15 for common "one scroll"
            // See https://doc.qt.io/qt-6/qml-qtquick-wheelhandler.html#rotation-prop
            let increment = 0;
            while (rotation >= 15) {
                rotation -= 15;
                increment++;
            }
            while (rotation <= -15) {
                rotation += 15;
                increment--;
            }
            const anchor = dropArea.target.childAt(event.x, event.y);
            if (Plasmoid.configuration.wheelEnabled === 3) {
                const loudest = anchor?.audioStreams?.reduce((loudest, stream) => Math.max(loudest, stream.volume), 0)
                const audio = dropArea.tasksRoot.audioModel;
                if (!audio) return;
                const step = (audio.normalVolume - audio.minimalVolume) * audio.globalConfig.volumeStep / 100;
                anchor?.audioStreams?.forEach((stream) => {
                    let delta = step * increment;
                    if (loudest > 0) {
                        delta *= stream.volume / loudest;
                    }
                    const volume = stream.volume + delta;
                    stream.model.Volume = Math.max(audio.minimalVolume, Math.min(volume, audio.normalVolume));
                    stream.model.Muted = volume === 0
                })
            return;
            }
            while (increment !== 0) {
                TaskManagerApplet.TaskTools.activateNextPrevTask(anchor, increment < 0, Plasmoid.configuration.wheelSkipMinimized, Plasmoid.configuration.wheelEnabled, dropArea.tasksRoot);
                increment += (increment < 0) ? 1 : -1;
            }
        }
    }
}
