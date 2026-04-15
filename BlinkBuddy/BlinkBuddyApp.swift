import SwiftUI

@main
struct BlinkBuddyApp: App {
    @StateObject private var timerManager = TimerManager()

    var body: some Scene {
        MenuBarExtra {
            // This displays the current count in the dropdown menu
            Text("Time active: \(timerManager.secondsElapsed)s")
            
            if timerManager.showWaitAlert {
                Text("⚠️ TAKE A BREAK!")
                    .foregroundColor(.red)
            }

            Divider()

            Button("Reset Timer") {
                timerManager.resetTimer()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            // This part changes the icon in the actual bar
            HStack {
                Image(systemName: "eye.fill")
                // This shows the seconds right next to the eye!
                Text("\(timerManager.secondsElapsed)")
            }
        }
    }
}
