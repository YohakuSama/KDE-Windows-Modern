// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

const defaults = ["documents", "downloads", "music", "pictures", "videos",
                  "network", "home", "thispc", "settings"];
const legacy = ["home", "documents", "pictures", "music", "downloads",
                "recent", "thispc", "update", "terminal", "run"];

function locations(i18n) {
    return [
        { key: "documents", text: i18n("Documents"), icon: "document-new-symbolic", command: 'xdg-open "$(xdg-user-dir DOCUMENTS)"' },
        { key: "downloads", text: i18n("Downloads"), icon: "document-download-symbolic", command: 'xdg-open "$(xdg-user-dir DOWNLOAD)"' },
        { key: "music", text: i18n("Music"), icon: "audio-x-generic-symbolic", command: 'xdg-open "$(xdg-user-dir MUSIC)"' },
        { key: "pictures", text: i18n("Pictures"), icon: "image-x-generic-symbolic", command: 'xdg-open "$(xdg-user-dir PICTURES)"' },
        { key: "videos", text: i18n("Videos"), icon: "video-x-generic-symbolic", command: 'xdg-open "$(xdg-user-dir VIDEOS)"' },
        { key: "network", text: i18n("Network"), icon: "network-workgroup-symbolic", command: "dolphin network:/" },
        { key: "home", text: i18n("Personal folder"), icon: "folder-home-symbolic", command: 'xdg-open "$HOME"' },
        { key: "thispc", text: i18n("File Manager"), icon: "folder-open-symbolic", command: "dolphin" },
        { key: "settings", text: i18n("Settings"), icon: "configure-symbolic", command: "systemsettings" },
        // Preserve deliberately selected shortcuts from older releases.
        { key: "recent", text: i18n("Recent Items"), icon: "document-open-recent-symbolic", command: "dolphin recentlyused:/files" },
        { key: "update", text: i18n("Software Center"), icon: "system-software-install-symbolic", command: "plasma-discover" },
        { key: "terminal", text: i18n("Terminal"), icon: "utilities-terminal-symbolic", command: "konsole" },
        { key: "run", text: i18n("Run..."), icon: "system-run-symbolic", command: "krunner" }
    ];
}

function normalize(selected) {
    if (selected === null || selected === undefined) return defaults.slice();
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
