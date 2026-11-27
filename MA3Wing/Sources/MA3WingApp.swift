import SwiftUI

@main
struct MA3WingApp: App {
    @StateObject private var state = ConsoleState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
    }
}
