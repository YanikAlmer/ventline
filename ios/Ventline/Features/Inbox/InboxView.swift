import SwiftUI

/// Cross-project conversation overview: every thread in one place, grouped by
/// site so a crew working across several projects can still find things.
struct InboxView: View {
    let profile: Profile

    @State private var groups: [ProjectThreadGroup] = []
    @State private var attention: [AttentionItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if !attention.isEmpty {
                Section("Needs your attention") {
                    ForEach(attention) { item in
                        NavigationLink {
                            destination(projectId: item.projectId, taskId: item.taskId)
                        } label: {
                            AttentionRow(item: item)
                        }
                    }
                }
            }

            if isLoading && groups.isEmpty {
                ProgressView()
            } else if groups.isEmpty {
                ContentUnavailableView(
                    "No conversations yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Messages from your projects show up here.")
                )
            } else {
                ForEach(groups) { group in
                    Section {
                        if let thread = group.projectThread {
                            NavigationLink {
                                destination(projectId: thread.projectId, taskId: nil)
                            } label: {
                                InboxRow(thread: thread, isProjectThread: true)
                            }
                        }
                        ForEach(group.taskThreads) { thread in
                            NavigationLink {
                                destination(projectId: thread.projectId, taskId: thread.taskId)
                            } label: {
                                InboxRow(thread: thread, isProjectThread: false)
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.projectName)
                            Spacer()
                            if group.mentionCount > 0 {
                                Text("@\(group.mentionCount)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                            if group.unreadCount > 0 {
                                Text("\(group.unreadCount)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.accentColor))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Communication")
        .task { await reload() }
        .refreshable { await reload() }
        .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func destination(projectId: UUID, taskId: UUID?) -> some View {
        if let taskId {
            TaskDetailView(taskId: taskId, profile: profile)
        } else {
            ChatView(projectId: projectId, taskId: nil, profile: profile)
        }
    }

    private func reload() async {
        do {
            async let threads = InboxRepo.threads()
            async let items = InboxRepo.attention()
            groups = InboxRepo.group(try await threads)
            attention = try await items
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

private struct InboxRow: View {
    let thread: InboxThread
    let isProjectThread: Bool

    /// Media threads carry no body, so the preview needs a stand-in. System
    /// bodies are stored in English and localized at display time.
    private var preview: String {
        if let body = thread.lastPreview, !body.isEmpty {
            return thread.lastKind == .system ? localizedSystemBody(body) : body
        }
        switch thread.lastKind {
        case .photo: return String(localized: "Photo")
        case .voice: return String(localized: "Voice message")
        default: return String(localized: "No messages yet")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !isProjectThread {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 2)
                    .padding(.vertical, 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(isProjectThread
                         ? String(localized: "Project chat")
                         : (thread.taskTitle ?? String(localized: "Task")))
                        .font(.subheadline.weight(thread.unreadCount > 0 ? .bold : .semibold))
                        .lineLimit(1)
                    Spacer()
                    if let at = thread.lastMessageAt {
                        Text(Timestamps.relative(at))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    if let sender = thread.lastSenderName {
                        Text("\(sender):")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if thread.unreadMentionCount > 0 {
                Text("@\(thread.unreadMentionCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
            }
            if thread.unreadCount > 0 {
                Text("\(thread.unreadCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
            }
        }
        .padding(.leading, isProjectThread ? 0 : 4)
    }
}

private struct AttentionRow: View {
    let item: AttentionItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.isMention ? "at.circle.fill" : "checklist")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.isMention
                     ? String(localized: "mentioned you")
                     : String(localized: "on your work package"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
                Text(item.body ?? String(localized: "Photo"))
                    .font(.caption)
                    .lineLimit(1)
            }
            Spacer()
            Text(Timestamps.relative(item.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
