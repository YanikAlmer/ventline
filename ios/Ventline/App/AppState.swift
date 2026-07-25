import Foundation
import Observation
import Supabase

/// Session + profile state driving the root navigation.
@Observable
@MainActor
final class AppState {
    enum Phase {
        case loading
        case signedOut
        /// Authenticated but no profile yet: create a company or redeem an invite.
        case onboarding
        /// Authenticated, but loading the profile failed (transient). Offer retry
        /// instead of falling through to onboarding, which would strand an
        /// existing member on a first-run screen.
        case loadFailed
        case ready(Profile)
    }

    private(set) var phase: Phase = .loading

    var profile: Profile? {
        if case .ready(let profile) = phase { return profile }
        return nil
    }

    private(set) var userId: UUID?

    private var authTask: Task<Void, Never>?

    func start() {
        guard authTask == nil else { return }
        authTask = Task {
            for await (event, session) in Supa.client.auth.authStateChanges {
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                    if let session {
                        self.userId = session.user.id
                        await self.loadProfile(userId: session.user.id)
                    } else {
                        self.phase = .signedOut
                    }
                case .signedOut, .userDeleted:
                    self.userId = nil
                    self.phase = .signedOut
                default:
                    break
                }
            }
        }
    }

    /// Re-check after onboarding (create company / redeem invite) or a retry.
    func refreshProfile() async {
        if let userId {
            phase = .loading
            await loadProfile(userId: userId)
        }
    }

    func signOut() async {
        try? await Supa.client.auth.signOut()
    }

    private func loadProfile(userId: UUID) async {
        do {
            let profiles: [Profile] = try await Supa.client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            if let profile = profiles.first {
                phase = .ready(profile)
            } else {
                phase = .onboarding
            }
        } catch {
            // A load failure must NOT be treated as "no profile" — that would
            // route an established member into onboarding. Keep a working
            // session as-is (e.g. a background token-refresh blip); otherwise
            // surface a retryable error.
            if case .ready = phase {
                // established session — leave it intact
            } else {
                phase = .loadFailed
            }
        }
    }
}
