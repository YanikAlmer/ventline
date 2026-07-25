import SwiftUI

struct ProjectDetailView: View {
    let projectId: UUID
    let profile: Profile

    @State private var project: Project?
    @State private var tasks: [JobTask] = []
    @State private var members: [ProjectMember] = []
    @State private var profilesById: [UUID: Profile] = [:]
    @State private var showNewTask = false
    @State private var showMembers = false

    private var grouped: [(status: TaskStatus, tasks: [JobTask])] {
        [TaskStatus.inProgress, .blocked, .todo, .done, .approved].compactMap { status in
            let matching = tasks.filter { $0.status == status }
            return matching.isEmpty ? nil : (status, matching)
        }
    }

    var body: some View {
        List {
            if let project {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            StatusPill(text: project.status.label, color: project.status.color)
                            Spacer()
                            if profile.role.canManageTasks {
                                statusMenu(project)
                            }
                        }
                        if let address = project.address, !address.isEmpty {
                            Label(address, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let description = project.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    NavigationLink {
                        ChatView(projectId: projectId, taskId: nil, profile: profile)
                            .navigationTitle("Project chat")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("Project chat", systemImage: "bubble.left.and.bubble.right")
                    }
                    Button {
                        showMembers = true
                    } label: {
                        Label("Team (\(members.count))", systemImage: "person.2")
                    }
                }

                ForEach(grouped, id: \.status) { group in
                    Section("\(group.status.label) · \(group.tasks.count)") {
                        ForEach(group.tasks, id: \.id) { task in
                            NavigationLink {
                                TaskDetailView(taskId: task.id, profile: profile)
                            } label: {
                                TaskRow(task: task)
                            }
                        }
                    }
                }

                if tasks.isEmpty {
                    Section {
                        Text("No tasks yet.")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(project?.name ?? String(localized: "Project"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewTask) {
            NewTaskSheet(projectId: projectId, profile: profile, members: memberProfiles) {
                await reload()
            }
        }
        .sheet(isPresented: $showMembers) {
            MembersSheet(projectId: projectId, profile: profile, members: $members, profilesById: $profilesById)
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private var memberProfiles: [Profile] {
        members.compactMap { profilesById[$0.profileId] }
    }

    private func statusMenu(_ project: Project) -> some View {
        Menu {
            ForEach([ProjectStatus.planning, .active, .onHold, .completed, .archived], id: \.self) { status in
                Button(status.label) {
                    Task {
                        try? await ProjectRepo.setStatus(projectId: projectId, status: status)
                        await reload()
                    }
                }
            }
        } label: {
            Label("Change status", systemImage: "arrow.triangle.2.circlepath")
                .font(.footnote)
        }
    }

    private func reload() async {
        async let projectTask = ProjectRepo.project(id: projectId)
        async let tasksTask = TaskRepo.tasks(projectId: projectId)
        async let membersTask = ProjectRepo.members(projectId: projectId)
        do {
            let (project, tasks, members) = try await (projectTask, tasksTask, membersTask)
            self.project = project
            self.tasks = tasks
            self.members = members
            let all = try await PeopleRepo.companyMembers()
            profilesById = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        } catch {
            // Pull-to-refresh retries.
        }
    }
}

struct TaskRow: View {
    let task: JobTask

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.status.systemImage)
                .foregroundStyle(task.status.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .lineLimit(2)
                if let due = task.dueDate {
                    Text("Due \(due)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if task.visibleToCustomer {
                Image(systemName: "eye")
                    .font(.caption)
                    .foregroundStyle(.teal)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Project roster: view, add, remove members.
struct MembersSheet: View {
    let projectId: UUID
    let profile: Profile
    @Binding var members: [ProjectMember]
    @Binding var profilesById: [UUID: Profile]

    @Environment(\.dismiss) private var dismiss

    private var canManage: Bool { profile.role.canManageTasks }

    private var candidates: [Profile] {
        let memberIds = Set(members.map(\.profileId))
        return profilesById.values
            .filter { !memberIds.contains($0.id) }
            .sorted { $0.fullName < $1.fullName }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("On this project") {
                    ForEach(members, id: \.profileId) { member in
                        if let memberProfile = profilesById[member.profileId] {
                            HStack {
                                PersonRow(profile: memberProfile)
                                Spacer()
                                if canManage {
                                    Button(role: .destructive) {
                                        remove(member.profileId)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                }
                            }
                        }
                    }
                }

                if canManage, !candidates.isEmpty {
                    Section("Add from company") {
                        ForEach(candidates, id: \.id) { candidate in
                            HStack {
                                PersonRow(profile: candidate)
                                Spacer()
                                Button {
                                    add(candidate.id)
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func add(_ profileId: UUID) {
        Task {
            try? await ProjectRepo.addMember(projectId: projectId, profileId: profileId)
            members = (try? await ProjectRepo.members(projectId: projectId)) ?? members
        }
    }

    private func remove(_ profileId: UUID) {
        Task {
            try? await ProjectRepo.removeMember(projectId: projectId, profileId: profileId)
            members = (try? await ProjectRepo.members(projectId: projectId)) ?? members
        }
    }
}

struct PersonRow: View {
    let profile: Profile

    var body: some View {
        HStack(spacing: 10) {
            Text(profile.initials)
                .font(.caption.weight(.bold))
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(Color.accentColor)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.fullName)
                Text(profile.role.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
