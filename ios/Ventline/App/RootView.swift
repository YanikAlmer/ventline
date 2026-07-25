import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.phase {
        case .loading:
            ProgressView()
        case .signedOut:
            AuthView()
        case .onboarding:
            OnboardingView()
        case .loadFailed:
            ProfileLoadErrorView()
        case .ready(let profile):
            MainTabView(profile: profile)
        }
    }
}

/// Shown when the profile load fails for a signed-in user (transient error).
/// Offers a retry rather than dropping them into onboarding.
struct ProfileLoadErrorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Couldn't load your account")
                .font(.headline)
            Text("Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await appState.refreshProfile() }
            }
            .buttonStyle(.borderedProminent)
            Button("Sign out") {
                Task { await appState.signOut() }
            }
            .font(.footnote)
        }
        .padding(32)
    }
}

struct MainTabView: View {
    let profile: Profile

    var body: some View {
        if profile.role == .customer {
            // Customers get the read-only portal, not the working app.
            NavigationStack {
                CustomerPortalView()
            }
        } else {
            TabView {
                NavigationStack {
                    ProjectListView(profile: profile)
                }
                .tabItem { Label("Projects", systemImage: "building.2") }

                NavigationStack {
                    MyTasksView(profile: profile)
                }
                .tabItem { Label("My Tasks", systemImage: "checklist") }

                if profile.role.isOffice {
                    NavigationStack {
                        PeopleView(profile: profile)
                    }
                    .tabItem { Label("People", systemImage: "person.2") }
                }

                NavigationStack {
                    SettingsView(profile: profile)
                }
                .tabItem { Label("Settings", systemImage: "gearshape") }
            }
        }
    }
}
