// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

function browserAlias(value) {
    const key = String(value || "").trim().toLowerCase()
        .replace(/\.desktop$/, "").replace(/[._-]+/g, " ").replace(/\s+/g, " ");
    if (/^(?:(?:org )?mozilla )?firefox(?: nightly)?$/.test(key)) {
        const nightly = key.endsWith("nightly");
        return {name: nightly ? "Firefox Nightly" : "Mozilla Firefox",
            icon: nightly ? "firefox-nightly" : "firefox", fallback: "firefox"};
    }
    if (/^(?:(?:org )?mozilla )?firefox (?:developer edition|beta|esr)$/.test(key)) {
        const edition = key.endsWith("developer edition") ? "Developer Edition" : key.endsWith("beta") ? "Beta" : "ESR";
        return {name: "Firefox " + edition, icon: "firefox-" + edition.toLowerCase().replace(/ /g, "-"), fallback: "firefox"};
    }
    if (/^(?:(?:com )?microsoft edge|msedge)(?: (?:stable|beta|dev))?$/.test(key)) {
        const edition = key.endsWith("beta") ? "Beta" : key.endsWith("dev") ? "Dev" : "";
        return {name: "Microsoft Edge" + (edition ? " " + edition : ""),
            icon: "microsoft-edge" + (edition ? "-" + edition.toLowerCase() : ""), fallback: "microsoft-edge"};
    }
    if (/^(?:(?:com )?google )?chrome(?: stable)?$/.test(key))
        return {name: "Google Chrome", icon: "google-chrome", fallback: "audio-x-generic"};
    if (/^(?:org chromium )?chromium$/.test(key))
        return {name: "Chromium", icon: "chromium", fallback: "audio-x-generic"};
    return null;
}

// Resolve known desktop-entry aliases first. Never infer a browser from
// a track title, an unrelated app name containing "Firefox", or a URL.
function describe(identity, desktopEntry, iconName) {
    const name = String(identity || "").trim();
    const desktop = String(desktopEntry || "").trim().replace(/\.desktop$/i, "");
    const icon = String(iconName || "").trim();
    const generic = /^(?:audio-x-generic(?:-symbolic)?|emblem-music(?:-symbolic)?|application-x-executable(?:-symbolic)?|unknown)?$/i.test(icon);
    const known = browserAlias(desktop) || browserAlias(name);
    if (known) {
        // Keep an actual app-provided icon; only substitute a known alias
        // when the MPRIS backend has returned its generic fallback.
        return generic ? known : {name: known.name, icon: icon, fallback: known.icon};
    }
    return {name: name || desktop, icon: generic ? (desktop || "audio-x-generic") : icon,
        fallback: "audio-x-generic"};
}
