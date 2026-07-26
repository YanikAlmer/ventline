import SwiftUI

/// SwiftUI has no hook for the APNs token callbacks, so a minimal delegate
/// bridges them to PushManager.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in PushManager.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in PushManager.shared.didFailToRegister(error: error) }
    }
}

@main
struct VentlineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .task { appState.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Work recorded in a plant room should reach the office as soon as
            // the phone is useful again — which is usually the moment somebody
            // picks it up, not a network event.
            if phase == .active { OfflineQueue.shared.resume() }
        }
    }
}
