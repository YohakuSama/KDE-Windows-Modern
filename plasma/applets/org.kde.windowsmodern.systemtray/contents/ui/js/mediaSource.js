// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Preserve the real MPRIS session. The desktop entry is more reliable
// than raw browser build identifiers; only normalize recognized aliases.
function describe(identity, desktopEntry, iconName) {
    const name = String(identity || "").trim();
    const desktop = String(desktopEntry || "").replace(/\.desktop$/i, "").trim();
    const icon = String(iconName || "").trim();
    const key = (desktop + " " + name).toLowerCase();
    const generic = /^(?:audio-x-generic(?:-symbolic)?|emblem-music(?:-symbolic)?|application-x-executable(?:-symbolic)?|unknown)?$/i.test(icon);
    let known = null;
    if (/(?:^|[.\s_-])firefox[\s_-]+nightly(?:$|[.\s_-])/.test(key))
        known = {name: "Firefox Nightly", icon: "firefox-nightly", fallback: "firefox"};
    else if (/(?:^|[.\s_-])firefox(?:$|[.\s_-])/.test(key)) {
        if (/developer[\s_-]+edition/.test(key))
            known = {name: "Firefox Developer Edition", icon: "firefox-developer-edition", fallback: "firefox"};
        else if (/firefox[\s_-]+beta/.test(key))
            known = {name: "Firefox Beta", icon: "firefox-beta", fallback: "firefox"};
        else if (/firefox[\s_-]+esr/.test(key))
            known = {name: "Firefox ESR", icon: "firefox-esr", fallback: "firefox"};
        else known = {name: "Mozilla Firefox", icon: "firefox", fallback: "audio-x-generic"};
    } else if (/(?:^|[.\s_-])(?:microsoft[\s_.-]+edge|msedge)(?:$|[.\s_-])/.test(key)) {
        const beta = /(?:edge|msedge)[\s_-]+beta/.test(key);
        const dev = /(?:edge|msedge)[\s_-]+dev/.test(key);
        known = {name: beta ? "Microsoft Edge Beta" : dev ? "Microsoft Edge Dev" : "Microsoft Edge",
            icon: beta ? "microsoft-edge-beta" : dev ? "microsoft-edge-dev" : "microsoft-edge",
            fallback: "microsoft-edge"};
    } else if (/(?:^|[.\s_-])(?:google[\s_.-]+chrome|chrome)(?:$|[.\s_-])/.test(key))
        known = {name: "Google Chrome", icon: "google-chrome", fallback: "audio-x-generic"};
    else if (/(?:^|[.\s_-])chromium(?:$|[.\s_-])/.test(key))
        known = {name: "Chromium", icon: "chromium", fallback: "audio-x-generic"};

    if (known) {
        if (!generic) return {name: known.name, icon: icon, fallback: known.icon};
        return known;
    }
    return {name: name || desktop, icon: generic ? (desktop || "audio-x-generic") : icon,
        fallback: "audio-x-generic"};
}
