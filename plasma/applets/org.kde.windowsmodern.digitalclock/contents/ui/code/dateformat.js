/*
    Locale-aware date formats for the Windows Modern clock.

    SPDX-FileCopyrightText: 2026 Jeysef <jeysef@users.noreply.github.com>
    SPDX-License-Identifier: GPL-3.0-or-later
*/
.pragma library

// The locale's short date format with a four-digit year, as the Windows
// taskbar clock shows it ("11.11.2026" in cs_CZ, "11/11/2026" in en_US).
// Qt's short formats often use a two-digit year ("dd.MM.yy").
function shortDateFullYear(shortFormat) {
    return shortFormat.replace(/(^|[^y])yy(?!y)/g, "$1yyyy");
}

// The locale's long date format with the year removed, as the Windows 11
// clock flyout shows it ("Wednesday, November 11" in en_US, "středa
// 11. listopadu" in cs_CZ, "11月11日水曜日" in ja_JP). Removing the year from
// the locale's own pattern keeps the word order and grammatical case right,
// which a fixed pattern such as "dddd, MMMM d" does not.
function longDateWithoutYear(longFormat) {
    let f = longFormat;
    // Year at the start: "yyyy年M月d日dddd", "yyyy. MMMM d., dddd".
    f = f.replace(/^\s*y+\s*(?:年|년|\.)?\s*/, "");
    // Year at the end, with a literal word before it ("'de'") or after it
    // ("'г'."): "dddd, d 'de' MMMM 'de' yyyy", "dddd, d MMMM yyyy 'г'.",
    // "dddd, MMMM d, yyyy", "dddd d. MMMM yyyy".
    f = f.replace(/(?:\s*'[^']*')?[\s,]*y+\s*(?:'[^']*'\.?|年|년)?\s*$/, "");
    // Year somewhere in the middle (rare): drop it with one adjacent separator.
    f = f.replace(/[\s,]*y+(?:年|년)?/, "");
    return f.trim();
}


// Existing mode 1 is the Windows Modern theme default. Keep explicit
// choices 0 and 2; provide regional defaults as a separate choice (3).
function windowsShortDate() { return "yyyy/M/d"; }

function clockFormats(mode, regionalFormat) {
    if (mode === 0) return {time: "h:mm AP", seconds: "h:mm:ss AP"};
    if (mode === 1) return {time: "H:mm", seconds: "H:mm:ss"};
    if (mode === 2) return {time: "HH:mm", seconds: "HH:mm:ss"};
    const fmt = String(regionalFormat || "H:mm");
    const match = /m{1,2}/.exec(fmt);
    return {time: fmt, seconds: match
        ? fmt.slice(0, match.index + match[0].length) + ":ss" + fmt.slice(match.index + match[0].length)
        : "H:mm:ss"};
}

function calendarLocaleName(translated, fallback) {
    return /^[a-z]{2,3}([_-][A-Za-z]{2,4}){0,2}$/.test(translated)
        ? translated.replace(/-/g, "_") : fallback;
}

function calendarMonthTitle(locale, year, month) {
    if (/^zh(?:[_-]|$)/i.test(locale.name))
        return year + "年" + (month + 1) + "月";
    return locale.standaloneMonthName(month, Locale.LongFormat) + " " + year;
}

function calendarLongDate(locale, date) {
    if (/^zh(?:[_-]|$)/i.test(locale.name))
        return locale.toString(date, "M月d日 dddd");
    return locale.toString(date, longDateWithoutYear(locale.dateFormat(Locale.LongFormat)));
}
