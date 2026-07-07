import SwiftUI

@main
struct VentlineApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .task { appState.start() }
        }
    }
}
