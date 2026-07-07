import SwiftUI

/// Shown when a user is signed in but has no profile yet (e.g. signed up
/// without a valid invite code). Two ways in: found a company or join one.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    @State private var fullName = ""
    @State private var inviteCode = ""
    @State private var companyName = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name", text: $fullName)
                        .textContentType(.name)
                } header: {
                    Text("Almost there")
                } footer: {
                    Text("Your account isn't linked to a company yet. Join with an invite code from your manager, or create a new company.")
                }

                Section("Join with an invite code") {
                    TextField("Invite code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Join company") {
                        redeem()
                    }
                    .disabled(isWorking || inviteCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("Or create a new company") {
                    TextField("Company name", text: $companyName)
                    Button("Create company") {
                        create()
                    }
                    .disabled(isWorking || companyName.trimmingCharacters(in: .whitespaces).isEmpty || fullName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await appState.signOut() }
                    }
                }
            }
            .navigationTitle("Set up")
        }
    }

    private func redeem() {
        run {
            let name = fullName.isEmpty ? "New member" : fullName
            let ok = try await OnboardingRepo.redeemInvite(
                code: inviteCode.uppercased().trimmingCharacters(in: .whitespaces),
                fullName: name
            )
            if !ok {
                throw NSError(domain: "Ventline", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "That invite code is invalid or expired. Ask your manager for a new one.",
                ])
            }
        }
    }

    private func create() {
        run {
            try await OnboardingRepo.createCompany(name: companyName, fullName: fullName)
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await operation()
                await appState.refreshProfile()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
