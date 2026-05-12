import XCTest
@testable import BrowserSwitcher

final class SchedulerTests: XCTestCase {
    private let schedule = Schedule(startHour: 9, startMinute: 0, endHour: 18, endMinute: 0, enabled: true)
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return calendar.date(from: comps)!
    }

    // 2026-05-11 is a Monday, 05-12 Tuesday, ... 05-16 Saturday, 05-17 Sunday.

    func test_weekdayBeforeStart_isFirefox_boundaryIsTodayStart() {
        let now = date(2026, 5, 12, 7, 30)
        let eval = Scheduler.evaluate(schedule, at: now, calendar: calendar)
        XCTAssertEqual(eval.slot, .outsideWindow)
        XCTAssertEqual(eval.nextBoundary, date(2026, 5, 12, 9, 0))
    }

    func test_weekdayInsideWindow_isChrome_boundaryIsTodayEnd() {
        let now = date(2026, 5, 12, 14, 0)
        let eval = Scheduler.evaluate(schedule, at: now, calendar: calendar)
        XCTAssertEqual(eval.slot, .inWindow)
        XCTAssertEqual(eval.nextBoundary, date(2026, 5, 12, 18, 0))
    }

    func test_weekdayAtStart_isChrome() {
        let now = date(2026, 5, 12, 9, 0)
        let eval = Scheduler.evaluate(schedule, at: now, calendar: calendar)
        XCTAssertEqual(eval.slot, .inWindow)
        XCTAssertEqual(eval.nextBoundary, date(2026, 5, 12, 18, 0))
    }

    func test_weekdayAtEnd_isFirefox() {
        let now = date(2026, 5, 12, 18, 0)
        let eval = Scheduler.evaluate(schedule, at: now, calendar: calendar)
        XCTAssertEqual(eval.slot, .outsideWindow)
        XCTAssertEqual(eval.nextBoundary, date(2026, 5, 13, 9, 0))
    }

    func test_weekdayAfterEnd_boundaryIsTomorrowStart() {
        let now = date(2026, 5, 12, 20, 0)
        let eval = Scheduler.evaluate(schedule, at: now, calendar: calendar)
        XCTAssertEqual(eval.slot, .outsideWindow)
        XCTAssertEqual(eval.nextBoundary, date(2026, 5, 13, 9, 0))
    }

    func test_fridayAfterEnd_boundaryIsMondayStart() {
        let now = date(2026, 5, 15, 20, 0) // Friday
        let eval = Scheduler.evaluate(schedule, at: now, calendar: calendar)
        XCTAssertEqual(eval.slot, .outsideWindow)
        XCTAssertEqual(eval.nextBoundary, date(2026, 5, 18, 9, 0))
    }

    func test_saturday_isFirefox_boundaryIsMondayStart() {
        let now = date(2026, 5, 16, 12, 0)
        let eval = Scheduler.evaluate(schedule, at: now, calendar: calendar)
        XCTAssertEqual(eval.slot, .outsideWindow)
        XCTAssertEqual(eval.nextBoundary, date(2026, 5, 18, 9, 0))
    }

    func test_sunday_isFirefox_boundaryIsMondayStart() {
        let now = date(2026, 5, 17, 23, 30)
        let eval = Scheduler.evaluate(schedule, at: now, calendar: calendar)
        XCTAssertEqual(eval.slot, .outsideWindow)
        XCTAssertEqual(eval.nextBoundary, date(2026, 5, 18, 9, 0))
    }
}
