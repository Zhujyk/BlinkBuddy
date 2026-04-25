import AppKit
import XCTest
@testable import BlinkBuddy

@MainActor
final class ActivityMonitorTests: XCTestCase {
    func testWorkspaceNotificationsUpdateLifecycleStatus() async {
        let notificationCenter = NotificationCenter()
        let idleSeconds = LockedValue<TimeInterval>(0)
        let timerFactory = TestRepeatingTimerFactory()
        let monitor = ActivityMonitor(
            workspaceNotificationCenter: notificationCenter,
            idleThreshold: 60,
            recoveryCheckInterval: 45,
            idleTimeProvider: { idleSeconds.value },
            repeatingTimerFactory: timerFactory.makeTask
        )
        var events: [ActivityEvent] = []
        monitor.onEvent = { events.append($0) }

        monitor.start()
        XCTAssertEqual(monitor.currentStatus(), .active)

        idleSeconds.value = 90
        XCTAssertEqual(monitor.currentStatus(), .idle)

        notificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        await settleMainActor()
        XCTAssertEqual(events.last, .sessionDidResignActive)
        XCTAssertEqual(monitor.currentStatus(), .sessionInactive)

        notificationCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        await settleMainActor()
        XCTAssertEqual(events.last, .screensDidSleep)
        XCTAssertEqual(monitor.currentStatus(), .sleeping)

        idleSeconds.value = 0
        notificationCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        await settleMainActor()
        XCTAssertTrue(events.contains(.sessionDidBecomeActive))
        XCTAssertEqual(events.last, .didWake)
        XCTAssertEqual(monitor.currentStatus(), .active)
    }

    func testRecoveryMonitoringEmitsSparseIdleStateChecks() async {
        let notificationCenter = NotificationCenter()
        let idleSeconds = LockedValue<TimeInterval>(90)
        let timerFactory = TestRepeatingTimerFactory()
        let monitor = ActivityMonitor(
            workspaceNotificationCenter: notificationCenter,
            idleThreshold: 60,
            recoveryCheckInterval: 45,
            idleTimeProvider: { idleSeconds.value },
            repeatingTimerFactory: timerFactory.makeTask
        )
        var events: [ActivityEvent] = []
        monitor.onEvent = { events.append($0) }

        monitor.beginRecoveryMonitoring()

        XCTAssertEqual(timerFactory.createdTasks.count, 1)
        XCTAssertEqual(events.last, .idleStateChanged(.idle))

        idleSeconds.value = 0
        timerFactory.createdTasks[0].fire()
        await settleMainActor()
        XCTAssertEqual(events.last, .idleStateChanged(.active))

        monitor.endRecoveryMonitoring()
        XCTAssertTrue(timerFactory.createdTasks[0].isCancelled)
    }

    private func settleMainActor() async {
        await Task.yield()
        await Task.yield()
    }
}

private final class TestRepeatingTimerFactory {
    private(set) var createdTasks: [TestRepeatingTask] = []

    func makeTask(
        interval _: TimeInterval,
        leeway _: TimeInterval,
        handler: @escaping @Sendable () -> Void
    ) -> any ActivityScheduledTask {
        let task = TestRepeatingTask(handler: handler)
        createdTasks.append(task)
        return task
    }
}

private final class TestRepeatingTask: ActivityScheduledTask {
    private let handler: @Sendable () -> Void
    private(set) var isCancelled = false

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    func cancel() {
        isCancelled = true
    }

    func fire() {
        guard !isCancelled else {
            return
        }

        handler()
    }
}

private final class LockedValue<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
