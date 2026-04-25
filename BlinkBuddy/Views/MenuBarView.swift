import SwiftUI

struct MenuBarView: View {
    @ObservedObject var breakEngine: BreakEngine
    let quitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(statusTitle)
                .font(.headline)

            Text(statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if breakEngine.state == .breakDue {
                BreakupPopupView()
            }

            Divider()

            Button(primaryActionTitle, action: primaryAction)

            Button("Quit BlinkBuddy", action: quitAction)
        }
        .padding(.vertical, 4)
        .frame(minWidth: 240, alignment: .leading)
    }

    private var statusTitle: String {
        switch breakEngine.state {
        case .ready:
            return "BlinkBuddy is ready"
        case .tracking:
            return "Tracking active time"
        case .idlePaused:
            return "Tracking paused"
        case .breakDue:
            return "Break due now"
        }
    }

    private var statusMessage: String {
        switch breakEngine.state {
        case .ready:
            return "Start a focused session when you're ready."
        case .tracking:
            return "The menu bar stays quiet while the engine tracks your work."
        case .idlePaused(let reason):
            switch reason {
            case .userIdle:
                return "Tracking pauses while you're away from the keyboard."
            case .sessionInactive:
                return "Tracking pauses while your session is inactive."
            case .systemSleep:
                return "Tracking pauses while your Mac is asleep."
            }
        case .breakDue:
            return "Take a short 20-20-20 break, then start your next session."
        }
    }

    private var primaryActionTitle: String {
        switch breakEngine.state {
        case .breakDue:
            return "Start Next Session"
        case .ready, .tracking, .idlePaused:
            return "Start or Reset Session"
        }
    }

    private func primaryAction() {
        switch breakEngine.state {
        case .breakDue:
            breakEngine.markBreakHandled()
        case .ready, .tracking, .idlePaused:
            breakEngine.reset()
        }
    }
}
