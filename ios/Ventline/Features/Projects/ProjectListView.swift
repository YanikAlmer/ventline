import SwiftUI

struct ProjectListView: View {
    let profile: Profile

    @State private var projects: [ProjectOverview] = []
    @State private var isLoading = true
    @State private var showNewProject = false
    @State private var filter: ProjectStatus?

    private var filtered: [ProjectOverview] {
        guard let filter else {
            // Default view hides archived jobs.
            return projects.filter { $0.status != .archived }
        }
        return projects.filter { $0.status == filter }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                filterBar

                if isLoading && projects.isEmpty {
                    ProgressView().padding(.top, 60)
                } else if filtered.isEmpty {
                    ContentUnavailableView(
                        "No projects",
                        systemImage: "building.2",
                        description: Text(profile.role.isOffice
                            ? "Create your first project to get started."
                            : "You'll see projects here once you're added to one.")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(filtered, id: \.id) { overview in
                        NavigationLink(value: overview) {
                            ProjectCard(overview: overview)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .navigationTitle("Projects")
        .navigationDestination(for: ProjectOverview.self) { overview in
            if let id = overview.id {
                ProjectDetailView(projectId: id, profile: profile)
            }
        }
        .toolbar {
            if profile.role.isOffice {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet(profile: profile) {
                await reload()
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "All")
                ForEach([ProjectStatus.active, .planning, .onHold, .completed, .archived], id: \.self) { status in
                    filterChip(status, label: status.label)
                }
            }
        }
    }

    private func filterChip(_ status: ProjectStatus?, label: String) -> some View {
        Button {
            filter = status
        } label: {
            Text(label)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(filter == status ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(filter == status ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    private func reload() async {
        do {
            projects = try await ProjectRepo.overview()
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

struct ProjectCard: View {
    let overview: ProjectOverview

    private var total: Int { Int(overview.taskCount ?? 0) }
    private var finished: Int { Int((overview.doneCount ?? 0) + (overview.approvedCount ?? 0)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(overview.name ?? "Untitled")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let address = overview.address, !address.isEmpty {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let status = overview.status {
                    StatusPill(text: status.label, color: status.color)
                }
            }

            if total > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Double(finished), total: Double(total))
                        .tint(finished == total ? .green : .accentColor)
                    Text("\(finished) of \(total) tasks finished")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 14) {
                if let blocked = overview.blockedCount, blocked > 0 {
                    Label("\(blocked) blocked", systemImage: "exclamationmark.octagon")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if let members = overview.memberCount, members > 0 {
                    Label("\(members)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Timestamps.relative(overview.lastActivityAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct NewProjectSheet: View {
    let profile: Profile
    let onCreated: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var details = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Project name", text: $name)
                TextField("Address", text: $address)
                TextField("Description", text: $details, axis: .vertical)
                    .lineLimit(3...6)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("New project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(isWorking || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        isWorking = true
        Task {
            do {
                try await ProjectRepo.create(
                    name: name.trimmingCharacters(in: .whitespaces),
                    address: address.isEmpty ? nil : address,
                    description: details.isEmpty ? nil : details,
                    companyId: profile.companyId
                )
                await onCreated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }
}
