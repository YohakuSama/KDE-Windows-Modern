/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import plasma.applet.org.kde.plasma.icontasks as TaskManagerApplet

GridLayout {
    property bool animating: false

    rowSpacing: 0
    columnSpacing: 0

    property int animationsRunning: 0
    onAnimationsRunningChanged: {
        animating = animationsRunning > 0;
    }

    required property int count
    // The immediate parent's size follows this grid, so it cannot be used
    // to decide how many stripes the grid itself needs.
    required property real availableWidth
    required property real availableHeight

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    readonly property real minimumWidth: {
        const minimum = children
            .filter(item => item.visible && Number.isFinite(item.width) && item.width > 0)
            .reduce((value, item) => Math.min(value, item.width), Infinity);
        return Number.isFinite(minimum) ? minimum : 0;
    }

    readonly property int stripeCount: {
        const configured = Math.max(1, Plasmoid.configuration.maxStripes);
        if (configured === 1 || count <= 0) {
            return 1;
        }
        if (Plasmoid.configuration.forceStripes) {
            return configured;
        }

        const minWidth = Math.max(1, TaskManagerApplet.LayoutMetrics.preferredMinWidth());
        const minHeight = Math.max(1, TaskManagerApplet.LayoutMetrics.preferredMinHeight());
        const width = Math.max(0, availableWidth);
        const height = Math.max(0, availableHeight);

        // Use the applet's available extent and existing minimum cell sizes,
        // including when the model or its delegates are not yet ready.
        const stripeSizeLimit = Math.max(1, Math.floor(vertical ? width / minWidth : height / minHeight));
        const maxTasksPerStripe = Math.max(1, Math.ceil(vertical ? height / minHeight : width / minWidth));
        return Math.max(1, Math.min(Math.ceil(count / maxTasksPerStripe), configured, stripeSizeLimit));
    }

    readonly property int orthogonalCount: Math.max(1, Math.ceil(count / stripeCount))

    rows: vertical ? orthogonalCount : stripeCount
    columns: vertical ? stripeCount : orthogonalCount
}
