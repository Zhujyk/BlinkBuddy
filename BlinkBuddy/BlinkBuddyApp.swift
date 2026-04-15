import SwiftUI

@main
struct BlinkBuddyApp: App {
    // This connects your logic to your UI
//    @StateObject private var timerManager = TimerManager()

    var body: some Scene {
        // MenuBarExtra is the 'Main' scene for menu-bar-only apps
        MenuBarExtra("BlinkBuddy", systemImage: "eye.fill") {
            Button("Check Timer") {
//                print("Timer is at: \(timerManager.timeElapsed)")
            }
            Divider()
            Button("Quit BlinkBuddy") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
