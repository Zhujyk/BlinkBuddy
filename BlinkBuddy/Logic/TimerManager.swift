import Foundation
import Combine

class TimerManager: ObservableObject {
    // @Published tells SwiftUI: "Refresh the UI whenever this changes!"
    @Published var secondsElapsed = 0
    @Published var showWaitAlert = false
    
    private var timer: Timer?
    
    // Set this to 10 for a quick 10-second test!
    let breakInterval = 5

    init() {
        startTimer()
    }

    func startTimer() {
        stopTimer()
        
        // Fires every 1 second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.secondsElapsed += 1
            
            // Check if it's time for a break
            if self.secondsElapsed >= self.breakInterval {
                self.showWaitAlert = true
                self.stopTimer()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func resetTimer() {
        secondsElapsed = 0
        showWaitAlert = false
        startTimer()
    }
}
