import Foundation
import Combine

class TimerManager2: ObservableObject {
    // These tell the UI to refresh
    @Published var secondsRemaining: Int = 0
    @Published var showWaitAlert = false
    
    private var targetTime: Date?
    private var displayTimer: Timer? // For the live countdown
    private var breakTimer: Timer?   // The actual "Deadline" alarm
    
    // Set to 10 seconds for testing; 1200 for 20 minutes
    let breakInterval: TimeInterval = 10

    func startTimer() {
        stopTimer() // Always clean up before starting
        
        // 1. Set the "Deadline" (Now + 10 seconds)
        targetTime = Date().addingTimeInterval(breakInterval)
        secondsRemaining = Int(breakInterval)
        showWaitAlert = false

        // 2. The "Silent Assassin": Fires exactly once when the break is due
        breakTimer = Timer(fireAt: targetTime!, interval: 0, target: self, selector: #selector(triggerBreak), userInfo: nil, repeats: false)
        RunLoop.main.add(breakTimer!, forMode: .common)

        // 3. The "UI Helper": Updates the menu bar digits so the user isn't confused
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateCountdown()
        }
    }

    @objc private func triggerBreak() {
        showWaitAlert = true
        stopTimer()
    }

    private func updateCountdown() {
        guard let target = targetTime else { return }
        let diff = target.timeIntervalSince(Date())
        self.secondsRemaining = max(0, Int(diff))
    }

    func stopTimer() {
        breakTimer?.invalidate()
        displayTimer?.invalidate()
        breakTimer = nil
        displayTimer = nil
    }
}
