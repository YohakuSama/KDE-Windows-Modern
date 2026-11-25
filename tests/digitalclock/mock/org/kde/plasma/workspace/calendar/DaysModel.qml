// Mock DaysModel: no calendar events.
import QtQuick

QtObject {
    signal agendaUpdated(date updatedDate)
    property var events: []
    function setPluginsManager(manager) {}
    function eventsForDate(date) { return events; }
}
