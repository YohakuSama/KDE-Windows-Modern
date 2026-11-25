// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.kitemmodels as KItemModels
import "../code/startCategories.js" as Categories

Item {
    id: catalog
    visible: false
    width: 0
    height: 0
    property var entries: []
    property var nativeModel: null
    property var usageModel: null
    property var memberships: ({})
    property var popularity: []
    readonly property var rows: Categories.build(entries, memberships, popularity).map(bucket => ({
        key: bucket.key, label: labelForKey(bucket.key), entries: bucket.entries
    }))

    function labelForKey(key) {
        switch (key) {
        case "utilities": return i18n("Utilities & Tools");
        case "productivity": return i18n("Productivity");
        case "creativity": return i18n("Creativity");
        case "social": return i18n("Social");
        case "developer": return i18n("Developer Tools");
        case "information": return i18n("Information & Reading");
        case "games": return i18n("Games");
        case "entertainment": return i18n("Entertainment");
        case "accessibility": return i18n("Accessibility");
        default: return i18n("Other");
        }
    }
    function sizeOf(model) {
        if (!model) return 0;
        return typeof model.rowCount === "function" ? model.rowCount() : Number(model.count || 0);
    }
    function valueAt(model, row, name, fallback) {
        if (!model) return fallback;
        if (typeof model.get === "function") {
            const data = model.get(row);
            return data && data[name] !== undefined ? data[name] : fallback;
        }
        if (typeof model.index !== "function" || typeof model.data !== "function") return fallback;
        const role = model.KItemModels.KRoleNames.role(name);
        if (role === undefined || role < 0) return fallback;
        const value = model.data(model.index(row, 0), role);
        return value === undefined || value === null ? fallback : value;
    }
    function collect(model, parentCategory, map, depth) {
        if (!model || depth > 8) return;
        for (let i = 0; i < sizeOf(model); ++i) {
            const isParent = valueAt(model, i, "isParent", false);
            if (isParent && typeof model.modelForRow === "function") {
                const category = Categories.categoryForIcon(valueAt(model, i, "decoration", "")) || parentCategory;
                collect(model.modelForRow(i), category, map, depth + 1);
            } else if (parentCategory) {
                const key = Categories.desktopId(valueAt(model, i, "favoriteId", "") || valueAt(model, i, "url", ""));
                if (!key) continue;
                if (!map[key]) map[key] = [];
                if (!map[key].includes(parentCategory)) map[key].push(parentCategory);
            }
        }
    }
    function refresh() {
        const map = Object.create(null);
        collect(nativeModel, "", map, 0);
        memberships = map;
        const ranked = [];
        for (let i = 0; i < sizeOf(usageModel); ++i) {
            const id = valueAt(usageModel, i, "favoriteId", "") || valueAt(usageModel, i, "url", "");
            if (id) ranked.push(id);
        }
        popularity = ranked;
    }
    function scheduleRefresh() { refreshTimer.restart(); }
    onNativeModelChanged: scheduleRefresh()
    onUsageModelChanged: scheduleRefresh()
    Component.onCompleted: scheduleRefresh()
    Timer { id: refreshTimer; interval: 0; onTriggered: catalog.refresh() }
    Connections {
        target: catalog.nativeModel
        ignoreUnknownSignals: true
        function onModelReset() { catalog.scheduleRefresh(); }
        function onRowsInserted() { catalog.scheduleRefresh(); }
        function onRowsRemoved() { catalog.scheduleRefresh(); }
        function onDataChanged() { catalog.scheduleRefresh(); }
        function onLayoutChanged() { catalog.scheduleRefresh(); }
    }
    Connections {
        target: catalog.usageModel
        ignoreUnknownSignals: true
        function onModelReset() { catalog.scheduleRefresh(); }
        function onRowsInserted() { catalog.scheduleRefresh(); }
        function onRowsRemoved() { catalog.scheduleRefresh(); }
        function onRowsMoved() { catalog.scheduleRefresh(); }
        function onDataChanged() { catalog.scheduleRefresh(); }
        function onLayoutChanged() { catalog.scheduleRefresh(); }
    }
}
