import Foundation

public struct Schedule: Equatable, Sendable {
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var enabled: Bool

    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, enabled: Bool) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.enabled = enabled
    }

    public static let `default` = Schedule(
        startHour: 9, startMinute: 0,
        endHour: 18, endMinute: 0,
        enabled: true
    )
}

public struct ScheduleEvaluation: Equatable, Sendable {
    public let slot: Slot
    public let nextBoundary: Date
}

public enum Scheduler {
    /// Evaluates the schedule at `now`. Assumes `schedule.enabled == true`;
    /// the caller is responsible for the paused case.
    public static func evaluate(
        _ schedule: Schedule,
        at now: Date,
        calendar: Calendar = .current
    ) -> ScheduleEvaluation {
        let weekday = calendar.component(.weekday, from: now)
        let isWeekend = (weekday == 1 || weekday == 7) // Sun=1, Sat=7

        let todayStart = boundary(on: now, hour: schedule.startHour, minute: schedule.startMinute, calendar: calendar)
        let todayEnd = boundary(on: now, hour: schedule.endHour, minute: schedule.endMinute, calendar: calendar)

        if isWeekend {
            return ScheduleEvaluation(
                slot: .outsideWindow,
                nextBoundary: nextWeekdayStart(after: now, schedule: schedule, calendar: calendar)
            )
        }

        if now < todayStart {
            return ScheduleEvaluation(slot: .outsideWindow, nextBoundary: todayStart)
        }
        if now < todayEnd {
            return ScheduleEvaluation(slot: .inWindow, nextBoundary: todayEnd)
        }
        return ScheduleEvaluation(
            slot: .outsideWindow,
            nextBoundary: nextWeekdayStart(after: now, schedule: schedule, calendar: calendar)
        )
    }

    private static func boundary(on date: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }

    private static func nextWeekdayStart(after now: Date, schedule: Schedule, calendar: Calendar) -> Date {
        var candidate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        for _ in 0..<7 {
            let wd = calendar.component(.weekday, from: candidate)
            if wd != 1 && wd != 7 {
                return boundary(on: candidate, hour: schedule.startHour, minute: schedule.startMinute, calendar: calendar)
            }
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }
}
