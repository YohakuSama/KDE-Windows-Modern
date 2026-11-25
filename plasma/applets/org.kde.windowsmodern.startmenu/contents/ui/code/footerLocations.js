// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

const defaults = ["documents", "downloads", "music", "pictures", "videos",
                  "network", "home", "thispc", "settings"];
const legacy = ["home", "documents", "pictures", "music", "downloads",
                "recent", "thispc", "update", "terminal", "run"];

function locations(i18n) {
    return [
        { key: "documents", text: i18n("Documents"), icon: "wm-start-documents-symbolic", folder: "documents" },
        { key: "downloads", text: i18n("Downloads"), icon: "wm-start-downloads-symbolic", folder: "downloads" },
        { key: "music", text: i18n("Music"), icon: "wm-start-music-symbolic", folder: "music" },
        { key: "pictures", text: i18n("Pictures"), icon: "wm-start-pictures-symbolic", folder: "pictures" },
        { key: "videos", text: i18n("Videos"), icon: "wm-start-videos-symbolic", folder: "videos" },
        { key: "network", text: i18n("Network"), icon: "wm-start-network-symbolic", command: "dolphin network:/" },
        { key: "home", text: i18n("Personal folder"), icon: "wm-start-home-symbolic", folder: "home" },
        { key: "thispc", text: i18n("File Manager"), icon: "wm-start-thispc-symbolic", command: "dolphin" },
        { key: "settings", text: i18n("Settings"), icon: "wm-start-settings-symbolic", command: "systemsettings" },
        // Preserve deliberately selected shortcuts from older releases.
        { key: "recent", text: i18n("Recent Items"), icon: "document-open-recent-symbolic", command: "dolphin recentlyused:/files" },
        { key: "update", text: i18n("Software Center"), icon: "system-software-install-symbolic", command: "plasma-discover" },
        { key: "terminal", text: i18n("Terminal"), icon: "utilities-terminal-symbolic", command: "konsole" },
        { key: "run", text: i18n("Run..."), icon: "system-run-symbolic", command: "krunner" }
    ];
}

function normalize(selected) {
    if (selected === null || selected === undefined) return [];
    const values = Array.from(selected);
    if (values.join(",") === legacy.join(",")) return defaults.slice();
    return defaults.concat(["recent", "update", "terminal", "run"])
        .filter(key => values.indexOf(key) >= 0);
}

function toggle(selected, key, checked) {
    const values = normalize(selected).filter(value => value !== key);
    if (checked) values.push(key);
    return normalize(values);
}

// Route folders through Qt's actual standard user locations, not shell
// substitution or guessed English directory names. Commands still use KDE's
// existing executable backend. A failed/missing route must not close Start.
function invoke(location, resolveFolder, openUrl, execute) {
    if (!location) return false;
    if (location.folder) {
        const url = resolveFolder(location.folder);
        return !!url && String(url).length > 0 && !!openUrl(url);
    }
    if (location.command) return !!execute(location.command);
    return false;
}
