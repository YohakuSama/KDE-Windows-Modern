/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

.import org.kde.kirigami as Kirigami

const iconMargin = Math.round(Kirigami.Units.smallSpacing / 6);
const labelMargin = Kirigami.Units.smallSpacing;

// Layout callers supply live geometry/configuration inputs explicitly.
// No applet IDs, frame objects or instance state are resolved in this script.

function horizontalMargins(inputs) {
    return (inputs.frameLeft + inputs.frameRight) * (inputs.vertical ? 1 : inputs.spacingAdjustment);
}

function verticalMargins(inputs) {
    return (inputs.frameTop + inputs.frameBottom) * (inputs.vertical ? inputs.spacingAdjustment : 1);
}

function adjustMargin(inputs, height, margin) {
    const available = height - verticalMargins(inputs);

    if (available <= 0) {
        return 0;
    }
    if (available < Kirigami.Units.iconSizes.small) {
        return Math.min(Math.floor(height / 2),
            Math.floor((margin * (Kirigami.Units.iconSizes.small / available)) / 3));
    }

    return margin;
}

function maxStripes(inputs) {
    const length = inputs.vertical ? inputs.width : inputs.height;
    const minimum = inputs.vertical ? preferredMinWidth(inputs) : preferredMinHeight();

    return Math.max(1, Math.min(inputs.maxStripes, Math.floor(length / Math.max(1, minimum))));
}

function optimumCapacity(inputs) {
    const length = inputs.vertical ? inputs.height : inputs.width;
    const maximum = inputs.vertical ? preferredMaxHeight(inputs) : preferredMaxWidth(inputs);

    if (!inputs.vertical) {
        //  Fit more tasks in this case, that is possible to cut text, before combining tasks.
        return Math.ceil(length / maximum) * maxStripes(inputs) + 1;
    }

    return Math.floor(length / maximum) * maxStripes(inputs);
}

function preferredMinWidth(inputs) {
    let width = preferredMinLauncherWidth(inputs);

    if (!inputs.vertical && !inputs.iconsOnly) {
      width +=
          (Kirigami.Units.smallSpacing * 2) +
          (Kirigami.Units.gridUnit * 8);
    }

    return width;
}

function preferredMaxWidth(inputs) {
    if (inputs.iconsOnly) {
        if (inputs.vertical) {
            if (inputs.width === 0) {
                return 0
            }
            return inputs.width + verticalMargins(inputs);
        } else {
            if (inputs.height === 0) {
                return 0
            }
            return inputs.height + horizontalMargins(inputs);
        }
    }

    // Avoid doing a bunch of unnecessary work below in vertical mode
    if (inputs.vertical) {
        return preferredMinWidth(inputs);
    }

    // Visually, a large max item width on a tall panel looks cluttered even
    // with just a task or two open. This clutter is less pronounced on panels
    // lower in height, as there is generally more horizontal space.
    //
    // This allows for one default value for max item width where clutter is
    // reduced at low task counts for tall panels, while leaving low height
    // panels less affected (unaffected at 20px).
    const laneHeight = inputs.height / maxStripes(inputs); // correct for multiple rows
    let baseFactor = 1; // sane default in case something goes wrong
    switch (inputs.taskMaxWidth) {
    case 0: // narrow
        baseFactor = 1.2;
        break;
    case 1: // medium
        baseFactor = 1.6;
        break;
    case 2: // wide
        baseFactor = 2;
        break;
    }
    // For every pixel of height above 20, knock the factor down by 0.01. This
    // produces nice results for 20~50 pixels. Above 50, it suddenly feels like
    // it's shrinking a lot, and above 80 the Medium and Narrow settings would
    // end up setting the same width, so don't apply further reduction above 50.
    const factorReduction = (Math.min(50, laneHeight) - 20) * 0.01;
    // Clamp the minimum factor to 1 to ensure max width is always >= min width.
    // and the factor reduction to 0 so we don't ever increase the factor
    const factor = Math.max(1, baseFactor - Math.max(0, factorReduction));
    return Math.floor(preferredMinWidth(inputs) * factor);
}

function preferredMinHeight() {
    // TODO FIXME UPSTREAM: Port to proper font metrics for descenders once we have access to them.
    return Kirigami.Units.iconSizes.sizeForLabels + 4;
}

function preferredMaxHeight(inputs) {
    if (inputs.vertical) {
        let taskPreferredSize = 0;
        if (inputs.iconsOnly) {
            taskPreferredSize = inputs.width / maxStripes(inputs);
        } else {
            taskPreferredSize = Math.max(Kirigami.Units.iconSizes.sizeForLabels,
                                         Kirigami.Units.iconSizes.medium);
        }
        return verticalMargins(inputs) +
            Math.min(
                // Do not allow the preferred icon size to exceed the width of
                // the vertical task manager.
                inputs.width / maxStripes(inputs),
                taskPreferredSize);
    } else {
        return verticalMargins(inputs) +
            Math.min(
                Kirigami.Units.iconSizes.small * 3,
                Kirigami.Units.iconSizes.sizeForLabels * 3);
    }
}

function preferredHeightInPopup(inputs) {
    return verticalMargins(inputs) + Math.max(Kirigami.Units.iconSizes.sizeForLabels,
                                        Kirigami.Units.iconSizes.medium);
}

function spaceRequiredToShowText() {
    // gridUnit is the height of the default font, but only one isn't enough to
    // show anything but the elision character. 2 is too high and results in
    // text appearing only at excessively high widths.
    return Math.round(Kirigami.Units.gridUnit * 1.5);
}

function preferredMinLauncherWidth(inputs) {
    const baseWidth = inputs.vertical ? preferredMinHeight() : Math.min(inputs.height, Kirigami.Units.iconSizes.small * 3);

    return Math.max(1, baseWidth + horizontalMargins(inputs)
        - adjustMargin(inputs, baseWidth, inputs.frameTop) - adjustMargin(inputs, baseWidth, inputs.frameBottom));
}

function maximumContextMenuTextWidth() {
    return (Kirigami.Units.iconSizes.sizeForLabels * 28);
}

