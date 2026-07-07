import SwiftUI

/// Company roster + invites (owner/manager only — tab is hidden otherwise).
struct PeopleView: View {
    let profile: Profile

    @State private var members: [Profile] = []
    @State private var invites: [Invite] = []
    @State private var showInviteSheet = false

    var body: some View {
        List {
            Section("Team") {
                ForEach(members, id: \.id) { member in
                    HStack {
                        PersonRow(profile: member)
                        Spacer()
                        if canEditRole(of: member) {
                            roleMenu(member)
                        }
                    }
                }
            }

            if !invites.isEmpty {
                Section("Open invites") {
                    ForEach(invites, id: \.id) { invite in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(invite.code)
                                    .font(.system(.body, design: .monospaced).weight(.bold))
                                StatusPill(text: invite.role.label, color: .accentColor)
                                Spacer()
                                Button {
                                    revoke(invite)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                            }
                            if let name = invite.fullName {
                                Text("For \(name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Expires \(Timestamps.relative(invite.expiresAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = invite.code
                            } label: {
                                Label("Copy code", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("People")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInviteSheet = true
                } label: {
                    Label("Invite", systemImage: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteSheet(profile: profile) {
                await reload()
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func canEditRole(of member: Profile) -> Bool {
        guard member.id != profile.id else { return false }
        // Only owners touch owner roles — mirrors the database trigger.
        if member.role == .owner { return profile.role == .owner }
        return true
    }

    private func roleMenu(_ member: Profile) -> some View {
        Menu {
            ForEach(assignableRoles, id: \.self) { role in
                Button(role.label) {
                    Task {
                        try? await PeopleRepo.setRole(profileId: member.id, role: role)
                        await reload()
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var assignableRoles: [AppRole] {
        profile.role == .owner
            ? [.owner, .manager, .foreman, .worker, .customer]
            : [.manager, .foreman, .worker, .customer]
    }

    private func revoke(_ invite: Invite) {
        Task {
            try? await PeopleRepo.revokeInvite(id: invite.id)
            await reload()
        }
    }

    private func reload() async {
        members = (try? await PeopleRepo.companyMembers()) ?? members
        invites = (try? await PeopleRepo.openInvites()) ?? invites
    }
}
