// The clock's date lines: the flyout's long date without the year, and
// the panel's short date with a four-digit year.

import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.digitalclock/contents/ui/code/dateformat.js" as DateFormat

TestCase {
    name: "DateFormat"

    readonly property date day: new Date(2026, 10, 11)   // Wednesday 11 November 2026

    function dateLine(localeName) {
        const loc = Qt.locale(localeName);
        return loc.toString(day, DateFormat.longDateWithoutYear(loc.dateFormat(Locale.LongFormat)));
    }

    // Exact expectations for locales whose CLDR data is long-stable.
    function test_exact_data() {
        return [
            { tag: "cs_CZ", locale: "cs_CZ", expected: "středa 11. listopadu" },
            { tag: "en_US", locale: "en_US", expected: "Wednesday, November 11" },
        ];
    }
    function test_exact(data) {
        compare(dateLine(data.locale), data.expected);
    }

    // For every locale: no year left in the pattern or the output, and the
    // day of the month is still there.
    function test_noYear_data() {
        return ["cs_CZ", "sk_SK", "en_US", "en_GB", "de_DE", "fr_FR", "es_ES", "pt_BR", "pl_PL",
                "ru_RU", "uk_UA", "hu_HU", "ja_JP", "zh_CN", "ko_KR"].map(n => ({ tag: n, locale: n }));
    }
    function test_noYear(data) {
        const loc = Qt.locale(data.locale);
        const pattern = DateFormat.longDateWithoutYear(loc.dateFormat(Locale.LongFormat));
        verify(!/y/.test(pattern.replace(/'[^']*'/g, "")), "pattern still has a year token: " + pattern);
        const line = loc.toString(day, pattern);
        verify(line.indexOf("2026") === -1, "output contains the year: " + line);
        verify(line.indexOf("11") !== -1, "output lost the day of the month: " + line);
        verify(!/[,'\s]$/.test(line), "output ends with a dangling separator: " + line);
    }

    // The panel's date line: the locale's short date with a four-digit year.
    function test_shortDate_data() {
        return [
            { tag: "cs_CZ", locale: "cs_CZ", expected: "11.11.2026" },
            { tag: "en_US", locale: "en_US", expected: "11/11/2026" },
            { tag: "de_DE", locale: "de_DE", expected: "11.11.2026" },
        ];
    }
    function test_shortDate(data) {
        const loc = Qt.locale(data.locale);
        compare(loc.toString(day, DateFormat.shortDateFullYear(loc.dateFormat(Locale.ShortFormat))), data.expected);
    }

    function test_calendarLanguageFollowsInterface() {
        const loc = Qt.locale(DateFormat.calendarLocaleName("zh_CN", "en_US"));
        compare(loc.name, "zh_CN");
        compare(DateFormat.calendarMonthTitle(loc, 2026, 10, Locale.LongFormat), "2026年11月");
        compare(DateFormat.calendarLongDate(loc, new Date(2026, 10, 25), Locale.LongFormat), "11月25日 星期三");
        compare(DateFormat.calendarLocaleName("system", "en_US"), "en_US");
        compare(DateFormat.calendarLocaleName("invalid name", "en_US"), "en_US");
        compare(DateFormat.calendarMonthTitle(Qt.locale("en_US"), 2026, 10, Locale.LongFormat), "November 2026");
    }

    function test_windowsTaskbarClock() {
        const sample = new Date(2026, 8, 30, 5, 6, 7);
        compare(Qt.formatDate(sample, DateFormat.windowsShortDate()), "2026/9/30");
        const fmt = DateFormat.clockFormats(1, "h:mm AP");
        const loc = Qt.locale(DateFormat.clockLocaleName(1, "zh_CN"));
        compare(loc.toString(sample, fmt.time), "5:06 AM");
        compare(loc.toString(sample, fmt.seconds), "5:06:07 AM");
        compare(loc.toString(new Date(2026, 8, 30, 17, 6), fmt.time), "5:06 PM");
        compare(loc.toString(new Date(2026, 8, 30, 0, 6), fmt.time), "12:06 AM");
        compare(loc.toString(new Date(2026, 8, 30, 12, 6), fmt.time), "12:06 PM");
        compare(DateFormat.clockLocaleName(0, "zh_CN"), "zh_CN");
        compare(DateFormat.clockLocaleName(2, "zh_CN"), "zh_CN");
        compare(DateFormat.clockFormats(0, "HH:mm").time, "h:mm AP");
        compare(DateFormat.clockFormats(2, "h:mm AP").time, "HH:mm");
        compare(DateFormat.clockFormats(3, "h:mm AP").time, "h:mm AP");
    }

    function test_regionalTime_data() {
        return ["en_US", "en_GB", "zh_CN", "zh_TW", "de_DE", "ja_JP"].map(n => ({tag: n, locale: n}));
    }
    function test_regionalTime(data) {
        const loc = Qt.locale(data.locale);
        const pattern = loc.timeFormat(Locale.ShortFormat);
        const formats = DateFormat.clockFormats(3, pattern);
        const sample = new Date(2026, 10, 25, 19, 17, 9);
        compare(formats.time, pattern);
        compare(loc.toString(sample, formats.time), Qt.formatTime(sample, loc, Locale.ShortFormat));
        verify(loc.toString(sample, formats.seconds).length >= loc.toString(sample, formats.time).length);
        compare(DateFormat.clockLocaleName(3, data.locale), data.locale);
    }

    function test_uppercaseLatinDayPeriods() {
        const loc = Qt.locale("en_GB");
        const morning = new Date(2026, 10, 25, 5, 6, 7);
        const evening = new Date(2026, 10, 25, 22, 36, 7);
        compare(DateFormat.formatClockTime(loc, morning, "h:mm ap"), "5:06 AM");
        compare(DateFormat.formatClockTime(loc, evening, "h:mm ap"), "10:36 PM");
        compare(DateFormat.formatClockTime(loc, evening, "h:mm:ss ap"), "10:36:07 PM");
        compare(DateFormat.formatClockTime(loc, evening, "HH:mm"), "22:36");
        const chinese = Qt.locale("zh_CN");
        compare(DateFormat.formatClockTime(chinese, morning, "AP h:mm"), chinese.toString(morning, "AP h:mm"));
    }

    function test_shortDateFullYear_patterns() {
        compare(DateFormat.shortDateFullYear("dd.MM.yy"), "dd.MM.yyyy");
        compare(DateFormat.shortDateFullYear("yy-MM-dd"), "yyyy-MM-dd");
        compare(DateFormat.shortDateFullYear("d/M/yyyy"), "d/M/yyyy");
    }
}
