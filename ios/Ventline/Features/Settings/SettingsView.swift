import SwiftUI

struct SettingsView: View {
    let profile: Profile

    @Environment(AppState.self) private var appState
    @State private var fullName: String
    @State private var phone: String
    @State private var saved = false

    init(profile: Profile) {
        self.profile = profile
        _fullName = State(initialValue: profile.fullName)
        _phone = State(initialValue: profile.phone ?? "")
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $fullName)
                    .textContentType(.name)
                TextField("Phone", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                Button(saved ? "Saved ✓" : "Save changes") {
                    save()
                }
                .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("Account") {
                LabeledContent("Role", value: profile.role.label)
                Button("Sign out", role: .destructive) {
                    Task { await appState.signOut() }
                }
            }

            Section {
                LabeledContent("Version", value: appVersion)
            } footer: {
                Text("Ventline — job-site communication for trades teams.")
            }
        }
        .navigationTitle("Settings")
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "dev"
    }

    private func save() {
        Task {
            try? await PeopleRepo.updateProfile(
                profileId: profile.id,
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                phone: phone.isEmpty ? nil : phone
            )
            saved = true
            await appState.refreshProfile()
        }
    }
}
