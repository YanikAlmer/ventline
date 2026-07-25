import SwiftUI

/// Mint an invite code and share it (iOS share sheet / copy).
struct InviteSheet: View {
    let profile: Profile
    let onDone: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var role: AppRole = .worker
    @State private var fullName = ""
    @State private var projects: [ProjectOverview] = []
    @State private var selectedProjects: Set<UUID> = []
    @State private var createdCode: String?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var availableRoles: [AppRole] {
        profile.role == .owner
            ? [.owner, .manager, .foreman, .worker, .customer]
            : [.manager, .foreman, .worker, .customer]
    }

    var body: some View {
        NavigationStack {
            Group {
                if let createdCode {
                    codeResult(createdCode)
                } else {
                    form
                }
            }
            .navigationTitle("Invite someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(createdCode == nil ? "Cancel" : "Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            projects = (try? await ProjectRepo.overview()) ?? []
        }
        .onDisappear {
            Task { await onDone() }
        }
    }

    private var form: some View {
        Form {
            Section {
                Picker("Role", selection: $role) {
                    ForEach(availableRoles, id: \.self) { role in
                        Text(role.label).tag(role)
                    }
                }
                TextField("Name (optional)", text: $fullName)
            } footer: {
                if role == .customer {
                    Text("Customers only see tasks and photos you explicitly share, and only for the projects you pick below.")
                }
            }

            Section("Give access to projects") {
                if projects.isEmpty {
                    Text("No projects yet").foregroundStyle(.secondary)
                }
                ForEach(projects, id: \.id) { project in
                    if let id = project.id {
                        Button {
                            if selectedProjects.contains(id) {
                                selectedProjects.remove(id)
                            } else {
                                selectedProjects.insert(id)
                            }
                        } label: {
                            HStack {
                                Text(project.name ?? String(localized: "Untitled"))
                                Spacer()
                                if selectedProjects.contains(id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            Button {
                create()
            } label: {
                if isWorking {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Create invite code")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(isWorking || (role == .customer && selectedProjects.isEmpty))
        }
    }

    private func codeResult(_ code: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Share this code")
                .font(.headline)
            Text(code)
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .kerning(4)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text("They enter it when signing up in the Ventline app. The code expires in 14 days.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                ShareLink(
                    item: String(
                        format: String(localized: "Join our team on Ventline! Sign up with invite code: %@"),
                        code
                    )
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
    }

    private func create() {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                let result = try await PeopleRepo.createInvite(
                    role: role,
                    fullName: fullName.isEmpty ? nil : fullName,
                    projectIds: Array(selectedProjects)
                )
                createdCode = result.code
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
