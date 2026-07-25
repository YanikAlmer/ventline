import Foundation
import Observation
import Supabase
import UIKit
import UserNotifications

/// APNs registration and permission.
///
/// Permission strategy is two-stage and deliberately does NOT prompt on first
/// launch, when the user has no idea what the app is worth:
///
///  1. Provisional authorization the moment a signed-in profile is ready. This
///     shows NO system dialog at all — notifications arrive quietly in
///     Notification Centre with "Keep"/"Turn off" buttons on them.
///  2. Promotion to a real prompt later, at a moment of proven value (see
///     `promoteIfEarned`), by which time the crew has seen the app deliver
///     something they cared about.
///
/// The token is stored against an install_id rather than a profile, so
/// reinstalling or signing in as somebody else on a shared handset moves the
/// registration instead of leaving two live rows pointing at one device.
@Observable
@MainActor
final class PushManager: NSObject {
    static let shared = PushManager()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastError: String?

    /// Stable per-installation id. Regenerated only on reinstall, which is
    /// exactly when the APNs token changes anyway.
    private var installId: UUID {
        let key = "ventline.installId"
        if let existing = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: existing) {
            return uuid
        }
        let fresh = UUID()
        UserDefaults.standard.set(fresh.uuidString, forKey: key)
        return fresh
    }

    /// The token APNs last handed us, held until a profile is signed in.
    private var pendingToken: String?
    private var isSignedIn = false

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Call once a profile is loaded. Silent: no dialog is shown.
    func start() async {
        isSignedIn = true
        await refreshStatus()

        if authorizationStatus == .notDetermined {
            do {
                _ = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge, .provisional])
            } catch {
                lastError = error.localizedDescription
            }
            await refreshStatus()
        }

        // Registering is safe even when provisional: APNs still issues a token.
        UIApplication.shared.registerForRemoteNotifications()

        // A token that arrived before sign-in is now usable.
        if let token = pendingToken {
            await register(token: token)
        }
    }

    func stop() {
        isSignedIn = false
        pendingToken = nil
    }

    /// Promote provisional authorization to a real prompt. Call at a moment the
    /// user has just seen the value — never on launch.
    func promoteIfEarned() async {
        await refreshStatus()
        guard authorizationStatus == .provisional else { return }
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            lastError = error.localizedDescription
        }
        await refreshStatus()
    }

    func refreshStatus() async {
        authorizationStatus = await UNUserNotificationCenter.current()
            .notificationSettings().authorizationStatus
    }

    /// Called from the app delegate adaptor once APNs answers.
    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard isSignedIn else {
            // Sign-in has not finished; keep it until it has.
            pendingToken = token
            return
        }
        Task { await register(token: token) }
    }

    func didFailToRegister(error: Error) {
        lastError = error.localizedDescription
    }

    private func register(token: String) async {
        pendingToken = nil
        struct Params: Encodable {
            let pInstallId: UUID
            let pPlatform: String
            let pPushToken: String
            let pApnsEnvironment: String
            let pLocale: String
            let pAppVersion: String?

            enum CodingKeys: String, CodingKey {
                case pInstallId = "p_install_id"
                case pPlatform = "p_platform"
                case pPushToken = "p_push_token"
                case pApnsEnvironment = "p_apns_environment"
                case pLocale = "p_locale"
                case pAppVersion = "p_app_version"
            }
        }

        do {
            try await Supa.client
                .rpc("register_device", params: Params(
                    pInstallId: installId,
                    pPlatform: "ios",
                    pPushToken: token,
                    pApnsEnvironment: Self.apnsEnvironment,
                    // The device language, so the server can format copy the
                    // recipient actually reads — not the sender's language.
                    pLocale: Bundle.main.preferredLocalizations.first ?? "de",
                    pAppVersion: Bundle.main
                        .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ))
                .execute()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// A debug build talks to the APNs sandbox; a release build does not. Sending
    /// a sandbox token to the production host is the classic silent-failure.
    private static var apnsEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}

extension PushManager: UNUserNotificationCenterDelegate {
    /// Show the banner even while the app is open: a jobsite message arriving
    /// in another project still matters.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Pull the two values out here: [AnyHashable: Any] is not Sendable, so
        // capturing the whole dictionary across the actor hop is an error under
        // the Swift 6 language mode.
        let info = response.notification.request.content.userInfo
        let projectId = (info["project_id"] as? String).flatMap(UUID.init(uuidString:))
        let taskId = (info["task_id"] as? String).flatMap(UUID.init(uuidString:))
        guard let projectId else { return }

        await MainActor.run {
            PushRouter.shared.pending = PushRouter.Destination(
                projectId: projectId, taskId: taskId)
        }
    }
}

/// Where a tapped notification should take the user. The views observe this
/// rather than the manager, so routing stays out of the delivery path.
@Observable
@MainActor
final class PushRouter {
    static let shared = PushRouter()

    struct Destination: Equatable {
        let projectId: UUID
        let taskId: UUID?
    }

    var pending: Destination?

    private init() {}
}
