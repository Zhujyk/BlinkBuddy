import SwiftUI

@main
struct BlinkBuddyApp: App {
    // This creates the manager and keeps it alive
    @StateObject private var timerManager = TimerManager2()

    var body: some Scene {
        MenuBarExtra {
            // --- DROPDOWN MENU ---
            if timerManager.showWaitAlert {
                Text("🚨 BREAK TIME! 🚨")
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            } else {
                Text("Next break in: \(timerManager.secondsRemaining)s")
            }
            
            Divider()
            
            Button("Start/Reset Timer") {
                timerManager.startTimer()
            }
            
            Button("Quit BlinkBuddy") {
                NSApplication.shared.terminate(nil)
            }
            
        } label: {
            // --- MENU BAR ICON ---
            HStack {
                Image(systemName: timerManager.showWaitAlert ? "eye.slash.fill" : "eye.fill")
                Text("\(timerManager.secondsRemaining)s")
            }
        }
    }
}
