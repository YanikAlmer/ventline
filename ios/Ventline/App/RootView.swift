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
        case .ready(let profile):
            MainTabView(profile: profile)
        }
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
