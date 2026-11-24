// Mock of org.kde.plasma.plasmoid: just the clock's calendar settings.
pragma Singleton
import QtQuick

QtObject {
    property QtObject configuration: QtObject {
        property int firstDayOfWeek: 1
        property bool showWeekNumbers: false
        property var enabledCalendarPlugins: []
        property int expandedWidth: 320
        property var selectedTimeZones: ["Local"]
        property bool showLocalTimezone: false
        property int displayTimezoneFormat: 0
        property int showSeconds: 0
    }
}
