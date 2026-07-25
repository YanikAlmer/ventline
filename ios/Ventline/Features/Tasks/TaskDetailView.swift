import SwiftUI

struct TaskDetailView: View {
    let taskId: UUID
    let profile: Profile

    @State private var task: JobTask?
    @State private var assignments: [TaskAssignment] = []
    @State private var profilesById: [UUID: Profile] = [:]
    @State private var chatModel: ChatViewModel?

    var body: some View {
        VStack(spacing: 0) {
            if let task {
                header(task)
                Divider()
                if let chatModel {
                    ChatViewBody(model: chatModel)
                }
            } else {
                ProgressView()
                    .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle(task?.title ?? String(localized: "Task"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    private func header(_ task: JobTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusPill(text: task.status.label, color: task.status.color)
                if task.visibleToCustomer {
                    Label("Customer sees this", systemImage: "eye")
                        .font(.caption)
                        .foregroundStyle(.teal)
                }
                Spacer()
                statusActions(task)
            }

            if let description = task.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 12) {
                if let due = task.dueDate {
                    Label("Due \(due)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !assignments.isEmpty {
                    Label(assigneeNames, systemImage: "person")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
    }

    private var assigneeNames: String {
        assignments
            .compactMap { profilesById[$0.profileId]?.fullName }
            .joined(separator: ", ")
    }

    /// Status controls respect the database rules: workers move their own
    /// tasks between todo/in progress/blocked/done; approval is for
    /// foremen and office roles.
    @ViewBuilder
    private func statusActions(_ task: JobTask) -> some View {
        let isWorker = profile.role == .worker

        Menu {
            if task.status != .inProgress, task.status != .approved || !isWorker {
                Button {
                    setStatus(.inProgress, note: "started work")
                } label: {
                    Label("Start", systemImage: "play")
                }
            }
            if task.status != .done, task.status != .approved {
                Button {
                    setStatus(.done, note: "marked the task as done")
                } label: {
                    Label("Mark done", systemImage: "checkmark.circle")
                }
            }
            if task.status != .blocked, task.status != .approved {
                Button {
                    setStatus(.blocked, note: "flagged the task as blocked")
                } label: {
                    Label("Blocked", systemImage: "exclamationmark.octagon")
                }
            }
            if profile.role.canManageTasks {
                if task.status == .done {
                    Button {
                        setStatus(.approved, note: "approved the task")
                    } label: {
                        Label("Approve", systemImage: "checkmark.seal")
                    }
                }
                if task.status == .approved {
                    Button {
                        setStatus(.inProgress, note: "reopened the task")
                    } label: {
                        Label("Reopen", systemImage: "arrow.uturn.backward")
                    }
                }
                Divider()
                Button {
                    toggleCustomerVisibility(task)
                } label: {
                    Label(
                        task.visibleToCustomer ? "Hide from customer" : "Show to customer",
                        systemImage: task.visibleToCustomer ? "eye.slash" : "eye"
                    )
                }
            }
        } label: {
            Label("Update", systemImage: "arrow.triangle.2.circlepath")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func setStatus(_ status: TaskStatus, note: String) {
        Task {
            do {
                try await TaskRepo.setStatus(taskId: taskId, status: status)
                // Thread event so the team sees the transition in context.
                chatModel?.sendSystem(note)
                await reload()
            } catch {
                chatModel?.errorMessage = error.localizedDescription
            }
        }
    }

    private func toggleCustomerVisibility(_ task: JobTask) {
        Task {
            try? await TaskRepo.setCustomerVisibility(taskId: taskId, visible: !task.visibleToCustomer)
            await reload()
        }
    }

    private func reload() async {
        do {
            let task = try await TaskRepo.task(id: taskId)
            self.task = task
            assignments = (try? await TaskRepo.assignments(taskId: taskId)) ?? []
            let people = (try? await PeopleRepo.companyMembers()) ?? []
            profilesById = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
            if chatModel == nil {
                let model = ChatViewModel(projectId: task.projectId, taskId: task.id, profile: profile)
                chatModel = model
                await model.loadInitial()
                model.startRealtime()
            }
        } catch {
            // Navigation back out is the recovery path.
        }
    }
}

/// Chat UI backed by an externally owned model (used inside TaskDetailView,
/// where the model must outlive view refreshes and feed system messages).
struct ChatViewBody: View {
    let model: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if model.canLoadOlder {
                            Button("Load earlier messages") {
                                Task { await model.loadOlder() }
                            }
                            .font(.footnote)
                            .padding(.top, 8)
                        }
                        ForEach(model.items) { item in
                            MessageBubbleView(item: item, model: model)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: model.items.count) {
                    if let last = model.items.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            ComposerBar(model: model)
        }
        .onDisappear {
            model.stopRealtime()
        }
    }
}
