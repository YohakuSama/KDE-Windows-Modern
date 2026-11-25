// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Windows 11 Start groups apps by type and use. Linux has no Microsoft
// application-category database, so map desktop IDs and freedesktop menu
// metadata rather than translated app names or icon artwork.
// https://blogs.windows.com/windows-insider/2025/06/09/announcing-windows-11-insider-preview-build-26200-5641-dev-channel/
const order = ["utilities", "productivity", "creativity", "social", "developer",
    "information", "games", "entertainment", "accessibility", "other"];

function desktopId(value) {
    return String(value || "").replace(/^applications:\/*/i, "")
        .replace(/[?#].*$/, "").split("/").pop().toLowerCase();
}

function appId(entry) {
    return desktopId(entry.favoriteId || entry.url);
}

const explicit = {
    utilities: ["systemsettings", "org.kde.systemsettings", "org.kde.discover",
        "org.kde.kcalc", "org.kde.kclock", "org.kde.spectacle", "org.kde.ark",
        "org.kde.plasma-systemmonitor", "org.kde.kinfocenter", "org.kde.partitionmanager",
        "org.kde.filelight", "org.kde.ksystemlog", "org.kde.kcharselect",
        "org.kde.isoimagewriter", "org.kde.kdeconnect", "org.kde.knotes"],
    productivity: ["org.kde.dolphin", "org.kde.kate", "org.kde.kwrite", "org.kde.kmail2",
        "org.kde.kontact", "org.kde.okular", "org.kde.korganizer", "org.kde.falkon",
        "org.mozilla.firefox", "firefox", "google-chrome", "chromium", "chromium-browser",
        "microsoft-edge", "com.microsoft.edge", "com.google.chrome", "libreoffice-writer",
        "libreoffice-calc", "libreoffice-impress", "org.libreoffice.libreoffice",
        "org.mozilla.thunderbird", "thunderbird"],
    creativity: ["org.kde.gwenview", "org.kde.krita", "org.kde.kolourpaint",
        "org.kde.digikam", "org.kde.kdenlive", "org.kde.kamoso", "org.kde.skanpage",
        "org.gimp.gimp", "org.inkscape.inkscape", "org.blender.blender", "com.obsproject.studio"],
    social: ["org.kde.neochat", "org.kde.tokodon", "org.telegram.desktop", "telegramdesktop",
        "com.discordapp.discord", "discord", "org.signal.signal", "signal-desktop"],
    developer: ["org.kde.konsole", "org.kde.yakuake", "org.kde.kdevelop", "com.visualstudio.code",
        "code", "code-oss", "com.vscodium.codium", "org.gnome.builder", "alacritty", "org.alacritty.alacritty",
        "com.mitchellh.ghostty", "org.wezfurlong.wezterm"],
    entertainment: ["org.videolan.vlc", "vlc", "io.mpv.mpv", "mpv", "org.kde.haruna",
        "org.kde.elisa", "org.kde.dragonplayer", "com.spotify.client", "spotify"],
    games: ["com.valvesoftware.steam", "steam", "net.lutris.lutris", "com.heroicgameslauncher.hgl"],
    accessibility: ["org.kde.kmag", "org.kde.kmouth", "org.kde.kmousetool", "org.gnome.orca",
        "orca"],
    information: ["org.kde.marble", "org.kde.kweather", "org.kde.akregator", "org.kde.kalzium"]
};

function explicitCategory(id) {
    const key = desktopId(id).replace(/\.desktop$/, "");
    for (const category of order) {
        if (explicit[category] && explicit[category].includes(key)) return category;
    }
    return "";
}

function categoryForIcon(icon) {
    const key = String(icon || "").toLowerCase().replace(/-symbolic$/, "");
    if (["preferences-desktop-accessibility", "applications-accessibility"].includes(key)) return "accessibility";
    if (["applications-development", "applications-programming"].includes(key)) return "developer";
    if (["applications-graphics", "applications-photography"].includes(key)) return "creativity";
    if (["applications-games", "applications-game"].includes(key)) return "games";
    if (["applications-multimedia", "applications-audio", "applications-video", "applications-music"].includes(key)) return "entertainment";
    if (["applications-office", "applications-internet", "applications-network"].includes(key)) return "productivity";
    if (["applications-education", "applications-science", "applications-reference", "applications-geography"].includes(key)) return "information";
    if (["applications-system", "applications-utilities", "applications-accessories", "preferences-system",
         "preferences-desktop", "applications-settings"].includes(key)) return "utilities";
    return "";
}

function build(entries, memberships, usage) {
    const ranks = Object.create(null);
    for (let i = 0; i < usage.length; ++i) {
        const id = desktopId(usage[i]);
        if (id && ranks[id] === undefined) ranks[id] = i;
    }
    const buckets = Object.create(null);
    for (const key of order) buckets[key] = [];
    // Every real source row appears exactly once; native KDE categories
    // can overlap, so choose the first preferred mapped category.
    for (const entry of entries) {
        const id = appId(entry);
        const candidates = memberships[id] || [];
        let key = explicitCategory(id);
        if (!key) {
            key = ["accessibility", "developer", "creativity", "games", "entertainment",
                "productivity", "information", "utilities"].find(c => candidates.includes(c)) || "other";
        }
        buckets[key].push(entry);
    }
    // Microsoft creates a separate category only when >=3 apps qualify.
    for (const key of order) {
        if (key !== "other" && buckets[key].length > 0 && buckets[key].length < 3) {
            buckets.other.push(...buckets[key]);
            buckets[key] = [];
        }
    }
    function rank(entry) { return ranks[appId(entry)] ?? Number.MAX_SAFE_INTEGER; }
    const result = [];
    for (const key of order) {
        if (!buckets[key].length) continue;
        const members = buckets[key].slice().sort((a,b) => rank(a)-rank(b)
            || String(a.display || "").localeCompare(String(b.display || ""))
            || a.index-b.index);
        result.push({key: key, entries: members, rank: rank(members[0])});
    }
    // Real local KActivities popularity, with a stable semantic fallback
    // when no usage record exists. No fabricated activity scores.
    result.sort((a,b) => a.rank-b.rank || order.indexOf(a.key)-order.indexOf(b.key));
    return result;
}
