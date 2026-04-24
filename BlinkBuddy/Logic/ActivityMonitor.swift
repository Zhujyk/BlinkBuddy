import AppKit
import CoreGraphics
import Foundation

enum ActivityStatus: Equatable {
    case active
    case idle
    case sessionInactive
    case sleeping
}

enum ActivityEvent: Equatable {
    case sessionDidResignActive
    case sessionDidBecomeActive
    case screensDidSleep
    case didWake
    case idleStateChanged(ActivityStatus)
}

@MainActor
protocol ActivityMonitoring: AnyObject {
    var onEvent: ((ActivityEvent) -> Void)? { get set }

    func start()
    func stop()
    func beginRecoveryMonitoring()
    func endRecoveryMonitoring()
    func currentStatus() -> ActivityStatus
}

protocol ActivityScheduledTask: AnyObject {
    func cancel()
}

private final class DispatchSourceRepeatingTask: ActivityScheduledTask {
    private let timer: DispatchSourceTimer

    nonisolated init(
        interval: TimeInterval,
        leeway: TimeInterval,
        queue: DispatchQueue,
        handler: @escaping @Sendable () -> Void
    ) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        let deadline = DispatchTime.now() + interval
        timer.schedule(
            deadline: deadline,
            repeating: interval,
            leeway: .milliseconds(Int(leeway * 1_000))
        )
        timer.setEventHandler(handler: handler)
        timer.activate()
        self.timer = timer
    }

    nonisolated func cancel() {
        timer.cancel()
    }
}

@MainActor
final class ActivityMonitor: ActivityMonitoring {
    typealias IdleTimeProvider = () -> TimeInterval
    typealias RepeatingTimerFactory = (
        _ interval: TimeInterval,
        _ leeway: TimeInterval,
        _ handler: @escaping @Sendable () -> Void
    ) -> any ActivityScheduledTask

    var onEvent: ((ActivityEvent) -> Void)?

    private let workspaceNotificationCenter: NotificationCenter
    private let idleThreshold: TimeInterval
    private let recoveryCheckInterval: TimeInterval
    private let idleTimeProvider: IdleTimeProvider
    private let repeatingTimerFactory: RepeatingTimerFactory
    private var observers: [NSObjectProtocol] = []
    private var recoveryTimer: (any ActivityScheduledTask)?
    private var sessionIsActive = true
    private var systemIsSleeping = false
    private var hasStarted = false

    init(
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        idleThreshold: TimeInterval = 60,
        recoveryCheckInterval: TimeInterval = 45,
        idleTimeProvider: @escaping IdleTimeProvider = ActivityMonitor.defaultIdleTimeProvider,
        repeatingTimerFactory: @escaping RepeatingTimerFactory = ActivityMonitor.makeRepeatingTimer
    ) {
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.idleThreshold = idleThreshold
        self.recoveryCheckInterval = recoveryCheckInterval
        self.idleTimeProvider = idleTimeProvider
        self.repeatingTimerFactory = repeatingTimerFactory
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true

        observers = [
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleSessionDidResignActive()
                }
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleSessionDidBecomeActive()
                }
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreensDidSleep()
                }
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleDidWake()
                }
            }
        ]
    }

    func stop() {
        observers.forEach(workspaceNotificationCenter.removeObserver)
        observers.removeAll()
        endRecoveryMonitoring()
        hasStarted = false
    }

    func beginRecoveryMonitoring() {
        guard recoveryTimer == nil else {
            return
        }

        recoveryTimer = repeatingTimerFactory(recoveryCheckInterval, 5) { [weak self] in
            Task { @MainActor [weak self] in
                self?.emitIdleStatus()
            }
        }

        emitIdleStatus()
    }

    func endRecoveryMonitoring() {
        recoveryTimer?.cancel()
        recoveryTimer = nil
    }

    func currentStatus() -> ActivityStatus {
        if systemIsSleeping {
            return .sleeping
        }

        if !sessionIsActive {
            return .sessionInactive
        }

        return idleTimeProvider() >= idleThreshold ? .idle : .active
    }

    private func handleSessionDidResignActive() {
        sessionIsActive = false
        onEvent?(.sessionDidResignActive)
    }

    private func handleSessionDidBecomeActive() {
        sessionIsActive = true
        systemIsSleeping = false
        onEvent?(.sessionDidBecomeActive)
    }

    private func handleScreensDidSleep() {
        systemIsSleeping = true
        onEvent?(.screensDidSleep)
    }

    private func handleDidWake() {
        systemIsSleeping = false
        onEvent?(.didWake)
    }

    private func emitIdleStatus() {
        onEvent?(.idleStateChanged(currentStatus()))
    }

    nonisolated private static func defaultIdleTimeProvider() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
    }

    nonisolated private static func makeRepeatingTimer(
        interval: TimeInterval,
        leeway: TimeInterval,
        handler: @escaping @Sendable () -> Void
    ) -> any ActivityScheduledTask {
        DispatchSourceRepeatingTask(
            interval: interval,
            leeway: leeway,
            queue: DispatchQueue(
                label: "BlinkBuddy.ActivityMonitor.Recovery",
                qos: .utility
            ),
            handler: handler
        )
    }
}
