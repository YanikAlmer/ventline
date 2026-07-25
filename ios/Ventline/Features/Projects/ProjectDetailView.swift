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
    @State private var newStepParent: JobTask?
    @State private var expandedPackages: Set<UUID> = []

    /// Work packages, grouped by status. Steps never appear here as peers of
    /// their package — they are reached through `WorkPackage.steps`.
    private var grouped: [(status: TaskStatus, packages: [WorkPackage])] {
        let all = WorkPackage.build(from: tasks)
        return [TaskStatus.inProgress, .blocked, .todo, .done, .approved].compactMap { status in
            let matching = all.filter { $0.task.status == status }
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

                if profile.role != .customer {
                    Section {
                        NavigationLink {
                            TimeTrackerView(projectId: projectId, profile: profile, tasks: tasks)
                        } label: {
                            Label("Hours", systemImage: "clock")
                        }
                        NavigationLink {
                            MaterialsView(projectId: projectId, profile: profile, tasks: tasks)
                        } label: {
                            Label("Material", systemImage: "shippingbox")
                        }
                        NavigationLink {
                            RapportListView(projectId: projectId, profile: profile)
                        } label: {
                            Label("Rapporte", systemImage: "doc.text")
                        }
                    }
                }

                ForEach(grouped, id: \.status) { group in
                    Section("\(group.status.label) · \(group.packages.count)") {
                        // The rows are emitted here rather than from a child
                        // view: a child returning several rows is folded into
                        // ONE List row, and its NavigationLink then swallows
                        // every tap meant for the buttons beside it.
                        ForEach(group.packages, id: \.id) { pkg in
                            NavigationLink {
                                TaskDetailView(taskId: pkg.task.id, profile: profile)
                            } label: {
                                TaskRow(task: pkg.task, stepProgress: pkg.progressLabel)
                            }

                            if expandedPackages.contains(pkg.id) {
                                ForEach(pkg.steps, id: \.id) { step in
                                    NavigationLink {
                                        TaskDetailView(taskId: step.id, profile: profile)
                                    } label: {
                                        StepRow(step: step)
                                    }
                                }
                            }

                            packageActionRow(pkg)
                        }
                    }
                }

                if tasks.isEmpty {
                    Section {
                        Text("No work packages yet.")
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
        .sheet(item: $newStepParent) { parent in
            NewTaskSheet(
                projectId: projectId, profile: profile, members: memberProfiles,
                parent: parent
            ) {
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

    /// One row under each package: expand/collapse when it has steps, and
    /// "Add step" — which opens the sheet directly rather than making the
    /// crew tap a control labelled "Add step" to reveal another one.
    @ViewBuilder
    private func packageActionRow(_ pkg: WorkPackage) -> some View {
        let isExpanded = expandedPackages.contains(pkg.id)
        HStack(spacing: 16) {
            if !pkg.steps.isEmpty {
                Button {
                    withAnimation {
                        if isExpanded {
                            expandedPackages.remove(pkg.id)
                        } else {
                            expandedPackages.insert(pkg.id)
                        }
                    }
                } label: {
                    Label(
                        isExpanded
                            ? String(localized: "Hide steps")
                            : String(localized: "Show steps"),
                        systemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )
                }
            }
            if profile.role.canManageTasks {
                Button {
                    newStepParent = pkg.task
                } label: {
                    Label("Add step", systemImage: "plus.circle")
                }
            }
            Spacer()
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.borderless)
        .listRowInsets(EdgeInsets(top: 4, leading: 44, bottom: 8, trailing: 16))
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
    var stepProgress: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.status.systemImage)
                .foregroundStyle(task.status.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    if let stepProgress {
                        Text(stepProgress)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let due = task.dueMomentLabel {
                        Text("Due \(due)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

struct StepRow: View {
    let step: JobTask

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: step.status.systemImage)
                .font(.caption)
                .foregroundStyle(step.status.color)
            Text(step.title)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            if let due = step.dueMomentLabel {
                Text(due)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
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
