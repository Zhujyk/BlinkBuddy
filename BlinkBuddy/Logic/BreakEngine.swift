import Combine
import Foundation

protocol BreakScheduledTask: AnyObject {
    func cancel()
}

protocol BreakDeadlineScheduling {
    func schedule(after interval: TimeInterval, handler: @escaping @MainActor () -> Void) -> any BreakScheduledTask
}

private final class DispatchSourceDeadlineTask: BreakScheduledTask {
    private let timer: DispatchSourceTimer

    nonisolated init(
        interval: TimeInterval,
        queue: DispatchQueue,
        handler: @escaping @Sendable () -> Void
    ) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, leeway: .milliseconds(250))
        timer.setEventHandler(handler: handler)
        timer.activate()
        self.timer = timer
    }

    nonisolated func cancel() {
        timer.cancel()
    }
}

struct DispatchSourceDeadlineScheduler: BreakDeadlineScheduling {
    nonisolated init() {}

    nonisolated func schedule(after interval: TimeInterval, handler: @escaping @MainActor () -> Void) -> any BreakScheduledTask {
        DispatchSourceDeadlineTask(
            interval: interval,
            queue: DispatchQueue(label: "BlinkBuddy.BreakEngine.Deadline", qos: .utility),
            handler: {
                Task { @MainActor in
                    handler()
                }
            }
        )
    }
}

@MainActor
final class BreakEngine: ObservableObject {
    enum PauseReason: Equatable {
        case userIdle
        case sessionInactive
        case systemSleep
    }

    enum State: Equatable {
        case ready
        case tracking
        case idlePaused(PauseReason)
        case breakDue
    }

    @Published private(set) var state: State = .ready
    @Published private(set) var secondsRemaining = 0
    @Published private(set) var showWaitAlert = false

    let breakInterval: TimeInterval
    let idleThreshold: TimeInterval

    private let now: () -> Date
    private let scheduler: any BreakDeadlineScheduling
    private let activityMonitor: any ActivityMonitoring
    private var scheduledDeadline: (any BreakScheduledTask)?
    private var activeTrackingStartedAt: Date?
    private var accumulatedActiveTime: TimeInterval = 0

    init(
        breakInterval: TimeInterval = 20 * 60,
        idleThreshold: TimeInterval = 60,
        recoveryCheckInterval: TimeInterval = 45,
        now: @escaping () -> Date = Date.init,
        scheduler: any BreakDeadlineScheduling = DispatchSourceDeadlineScheduler(),
        activityMonitor: (any ActivityMonitoring)? = nil
    ) {
        self.breakInterval = breakInterval
        self.idleThreshold = idleThreshold
        self.now = now
        self.scheduler = scheduler
        self.activityMonitor = activityMonitor ?? ActivityMonitor(
            idleThreshold: idleThreshold,
            recoveryCheckInterval: recoveryCheckInterval
        )

        self.activityMonitor.onEvent = { [weak self] event in
            self?.handleActivityEvent(event)
        }
        self.activityMonitor.start()
        publishCompatibilityState()
    }

    var isTracking: Bool {
        if case .tracking = state {
            return true
        }

        return false
    }

    var menuBarIconSystemName: String {
        showWaitAlert ? "eye.slash.fill" : "eye.fill"
    }

    func start() {
        beginTracking(resetAccumulatedTime: true)
    }

    func reset() {
        beginTracking(resetAccumulatedTime: true)
    }

    func markBreakHandled() {
        beginTracking(resetAccumulatedTime: true)
    }

    func handleSleep() {
        pauseTracking(for: .systemSleep)
    }

    func handleWake() {
        resumeTrackingIfActive()
    }

    func startTimer() {
        start()
    }

    func resetTimer() {
        reset()
    }

    func stopTimer() {
        shutdown()
        state = .ready
        publishCompatibilityState()
    }

    func shutdown() {
        cancelScheduledDeadline()
        activeTrackingStartedAt = nil
        accumulatedActiveTime = 0
        showWaitAlert = false
        activityMonitor.endRecoveryMonitoring()
        activityMonitor.stop()
        activityMonitor.onEvent = nil
    }

    func remainingActiveTime(referenceDate: Date? = nil) -> TimeInterval {
        let currentDate = referenceDate ?? now()
        let activeSlice: TimeInterval

        if let activeTrackingStartedAt {
            activeSlice = max(0, currentDate.timeIntervalSince(activeTrackingStartedAt))
        } else {
            activeSlice = 0
        }

        return max(0, breakInterval - accumulatedActiveTime - activeSlice)
    }

    func handleActivityEvent(_ event: ActivityEvent) {
        switch event {
        case .sessionDidResignActive:
            pauseTracking(for: .sessionInactive)
        case .screensDidSleep:
            pauseTracking(for: .systemSleep)
        case .didWake, .sessionDidBecomeActive:
            resumeTrackingIfActive()
        case .idleStateChanged(let status):
            switch status {
            case .active:
                resumeTrackingIfActive()
            case .idle:
                if isTracking {
                    pauseTracking(for: .userIdle)
                }
            case .sessionInactive:
                pauseTracking(for: .sessionInactive)
            case .sleeping:
                pauseTracking(for: .systemSleep)
            }
        }
    }

    private func beginTracking(resetAccumulatedTime: Bool) {
        cancelScheduledDeadline()
        activityMonitor.endRecoveryMonitoring()

        if resetAccumulatedTime {
            accumulatedActiveTime = 0
        }

        let currentDate = now()
        activeTrackingStartedAt = currentDate
        state = .tracking
        showWaitAlert = false

        scheduleNextBoundary(from: currentDate)
    }

    private func pauseTracking(for reason: PauseReason) {
        guard isTracking else {
            state = .idlePaused(reason)
            activityMonitor.beginRecoveryMonitoring()
            publishCompatibilityState()
            return
        }

        if let activeTrackingStartedAt {
            accumulatedActiveTime += max(0, now().timeIntervalSince(activeTrackingStartedAt))
        }

        activeTrackingStartedAt = nil
        cancelScheduledDeadline()
        activityMonitor.beginRecoveryMonitoring()
        state = .idlePaused(reason)
        publishCompatibilityState()
    }

    private func resumeTrackingIfActive() {
        guard case .idlePaused = state else {
            return
        }

        guard activityMonitor.currentStatus() == .active else {
            publishCompatibilityState()
            return
        }

        let currentDate = now()
        activityMonitor.endRecoveryMonitoring()
        activeTrackingStartedAt = currentDate
        state = .tracking
        showWaitAlert = false

        scheduleNextBoundary(from: currentDate)
    }

    private func scheduleNextBoundary(from currentDate: Date) {
        let remaining = remainingActiveTime(referenceDate: currentDate)

        guard remaining > 0 else {
            transitionToBreakDue()
            return
        }

        scheduledDeadline = scheduler.schedule(after: remaining) { [weak self] in
            self?.handleDeadlineReached()
        }

        publishCompatibilityState(referenceDate: currentDate)
    }

    private func handleDeadlineReached() {
        scheduledDeadline = nil

        switch activityMonitor.currentStatus() {
        case .active:
            accumulatedActiveTime = breakInterval
            activeTrackingStartedAt = nil
            transitionToBreakDue()
        case .idle:
            pauseTracking(for: .userIdle)
        case .sessionInactive:
            pauseTracking(for: .sessionInactive)
        case .sleeping:
            pauseTracking(for: .systemSleep)
        }
    }

    private func transitionToBreakDue() {
        cancelScheduledDeadline()
        activityMonitor.endRecoveryMonitoring()
        activeTrackingStartedAt = nil
        state = .breakDue
        publishCompatibilityState(referenceDate: now())
    }

    private func cancelScheduledDeadline() {
        scheduledDeadline?.cancel()
        scheduledDeadline = nil
    }

    private func publishCompatibilityState(referenceDate: Date? = nil) {
        showWaitAlert = state == .breakDue
        secondsRemaining = Int(remainingActiveTime(referenceDate: referenceDate).rounded(.up))
    }
}
