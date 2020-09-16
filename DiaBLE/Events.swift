import Foundation
import EventKit


class EventKit {

    /// Main app delegate
    var main: MainDelegate
    var store: EKEventStore = EKEventStore()
    var calendarTitles = [String]()

    init(main: MainDelegate) {
        self.main = main
    }


    // https://github.com/JohanDegraeve/xdripswift/blob/master/xdrip/Managers/Watch/WatchManager.swift

    func sync(handler: ((EKCalendar?) -> ())? = nil) {

        store.requestAccess(to: .event) { granted, error  in
            guard granted
                else {
                    self.main.debugLog("EventKit: access not granted")
                    return
            }

            guard EKEventStore.authorizationStatus(for: .event) == .authorized
                else {
                    self.main.log("EventKit: access to calendar events not authorized")
                    return
            }

            self.calendarTitles = self.store.calendars(for: .event)
                .filter { $0.allowsContentModifications }
                .map { $0.title }

            guard self.main.settings.calendarTitle != "" else { return }

            var calendar: EKCalendar?
            for storeCalendar in self.store.calendars(for: .event) {
                if storeCalendar.title == self.main.settings.calendarTitle {
                    calendar = storeCalendar
                    break
                }
            }

            if calendar == nil {
                calendar = self.store.defaultCalendarForNewEvents
            }
            let predicate = self.store.predicateForEvents(withStart: Calendar.current.date(byAdding: .year, value: -1, to: Date())!, end: Date(), calendars: [calendar!])  // Date.distantPast doesn't work
            for event in self.store.events(matching: predicate) {
                if let notes = event.notes {
                    if notes.contains("Created by DiaBLE") {
                        do {
                            try self.store.remove(event, span: .thisEvent)
                        } catch {
                            self.main.debugLog("EventKit: error while deleting calendar events created by DiaBLE: \(error.localizedDescription)")
                        }
                    }
                }
            }

            var currentGlucose = self.main.app.currentGlucose
            var title = currentGlucose > 0 ?
                "\(currentGlucose)" :
                (currentGlucose < 0 ?
                    "(\(-currentGlucose))" : "---")

            currentGlucose = abs(currentGlucose)
            if currentGlucose != 0 {
                title += "  \(self.main.settings.glucoseUnit)"
                title += "  \(OOP.Alarm(rawValue: self.main.app.oopAlarm)?.description ?? "")  \(OOP.TrendArrow(rawValue: self.main.app.oopTrend)?.symbol ?? "---")"

                // TODO: delta

                let event = EKEvent(eventStore: self.store)
                event.title = title
                event.notes = "Created by DiaBLE"
                event.startDate = Date()
                event.endDate = Date(timeIntervalSinceNow: TimeInterval(60 * self.main.settings.readingInterval + 5))
                event.calendar = calendar

                if self.main.settings.calendarAlarmIsOn {
                    if currentGlucose > 0 && (currentGlucose > Int(self.main.settings.alarmHigh) || currentGlucose < Int(self.main.settings.alarmLow)) {
                        let alarm = EKAlarm(relativeOffset: 1)
                        event.addAlarm(alarm)
                    }
                }

                do {
                    try self.store.save(event, span: .thisEvent)
                } catch {
                    self.main.log("EventKit: error while saving event: \(error.localizedDescription)")
                }
                handler?(calendar)
            }
        }
    }
}
