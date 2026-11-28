// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// The session greeter can start without the user catalog in its data path.
// Prefer the real KDE translation. Only use this local fallback for a
// Chinese UI locale, and never override an already translated string.
const chinese = {
    "Unlocking failed": "解锁失败",
    "Caps Lock is on": "大写锁定已开启",
    "Sleep": "睡眠",
    "Hibernate": "休眠",
    "Shut down": "关机",
    "Restart": "重启",
    "Power": "电源",
    "Password": "密码",
    "Show password": "显示密码",
    "Sign in": "登录",
    "(or scan your fingerprint on the reader)": "（或扫描你的指纹）",
    "(or scan your smartcard)": "（或扫描你的智能卡）",
    "Accessibility": "辅助功能",
    "Network": "网络"
};

function tr(source, translated, uiLanguage, localeName) {
    if (translated && translated !== source) return translated;
    const language = String(uiLanguage || localeName || "").toLowerCase();
    return /^zh(?:[-_]|$)/.test(language) && chinese[source] ? chinese[source] : source;
}
