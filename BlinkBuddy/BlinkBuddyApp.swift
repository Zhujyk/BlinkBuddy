import SwiftUI

@main
struct BlinkBuddyApp: App {
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private let runtime = BlinkBuddyRuntime(
        isRunningTests: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    )

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(!isRunningTests)) {
            if let breakEngine = runtime.breakEngine {
                MenuBarView(
                    breakEngine: breakEngine,
                    quitAction: { NSApplication.shared.terminate(nil) }
                )
            }
        } label: {
            Image(systemName: runtime.breakEngine?.menuBarIconSystemName ?? "eye.fill")
        }
    }
}

@MainActor
private struct BlinkBuddyRuntime {
    let breakEngine: BreakEngine?

    init(isRunningTests: Bool) {
        breakEngine = isRunningTests ? nil : BreakEngine()
    }
}
