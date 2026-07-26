import SwiftUI

/// Cross-project conversation overview: every thread in one place, grouped by
/// site so a crew working across several projects can still find things.
struct InboxView: View {
    let profile: Profile

    /// The three ways people ask "where was that": by site, by who said it, by
    /// what it said. Same three lenses as the web client.
    private enum Lens: String, CaseIterable {
        case project, person
        var label: String {
            switch self {
            case .project: String(localized: "By project")
            case .person: String(localized: "By person")
            }
        }
    }

    @State private var groups: [ProjectThreadGroup] = []
    @State private var attention: [AttentionItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var lens: Lens = .project
    @State private var query = ""
    @State private var hits: [SearchHit] = []
    @State private var people: [Profile] = []
    @State private var selectedPerson: Profile?
    @State private var personMessages: [PersonMessage] = []

    var body: some View {
        content
            .navigationTitle("Communication")
            .searchable(text: $query, prompt: Text("Search all messages"))
            .task(id: query) {
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 2 else {
                    hits = []
                    return
                }
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                hits = (try? await InboxRepo.search(query: trimmed)) ?? []
            }
            .task { await reload() }
            .refreshable { await reload() }
            .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        // Search wins over the lens while there is a query: someone typing in
        // the search field is not still browsing.
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchResults
        } else {
            switch lens {
            case .project: projectLens
            case .person: personLens
            }
        }
    }

    private var lensPicker: some View {
        Picker("Lens", selection: $lens) {
            ForEach(Lens.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 12))
        .listRowSeparator(.hidden)
    }

    private var searchResults: some View {
        List {
            if hits.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ForEach(hits) { hit in
                    NavigationLink {
                        destination(projectId: hit.projectId, taskId: hit.taskId, focus: hit.id)
                    } label: {
                        MessageHitRow(
                            text: hit.body, kind: hit.kind,
                            createdAt: hit.createdAt, trailing: nil)
                    }
                }
            }
        }
    }

    private var personLens: some View {
        List {
            lensPicker
            if let selectedPerson {
                Section {
                    Button {
                        self.selectedPerson = nil
                        personMessages = []
                    } label: {
                        Label(selectedPerson.fullName, systemImage: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                if personMessages.isEmpty {
                    ContentUnavailableView(
                        "Nothing shared yet",
                        systemImage: "bubble.left",
                        description: Text("No messages with this person in the last while.")
                    )
                } else {
                    ForEach(personMessages) { message in
                        NavigationLink {
                            destination(
                                projectId: message.projectId,
                                taskId: message.taskId,
                                focus: message.id)
                        } label: {
                            MessageHitRow(
                                text: message.body, kind: message.kind,
                                createdAt: message.createdAt,
                                trailing: message.isFrom
                                    ? String(localized: "from")
                                    : String(localized: "to"))
                        }
                    }
                }
            } else {
                Section("People") {
                    ForEach(people, id: \.id) { person in
                        Button {
                            selectedPerson = person
                            Task {
                                personMessages =
                                    (try? await InboxRepo.personMessages(profileId: person.id)) ?? []
                            }
                        } label: {
                            HStack {
                                Text(person.fullName)
                                Spacer()
                                Text(person.role.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task {
            if people.isEmpty {
                // Everyone in the company, minus yourself: the lens answers
                // "what have I exchanged with them", which is empty for you.
                people = ((try? await PeopleRepo.companyMembers()) ?? [])
                    .filter { $0.id != profile.id }
            }
        }
    }

    private var projectLens: some View {
        List {
            lensPicker
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
    }

    @ViewBuilder
    private func destination(
        projectId: UUID, taskId: UUID?, focus: UUID? = nil
    ) -> some View {
        if let taskId {
            TaskDetailView(taskId: taskId, profile: profile)
        } else {
            ChatView(projectId: projectId, taskId: nil, profile: profile, focusMessageId: focus)
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

/// One message, as it appears in a search result or the person lens.
private struct MessageHitRow: View {
    let text: String?
    let kind: MessageKind?
    let createdAt: String
    /// "from" / "to" in the person lens; nothing in search.
    let trailing: String?

    /// Media carries no body, so the row needs a stand-in rather than a blank.
    private var preview: String {
        if let text, !text.isEmpty {
            return kind == .system ? localizedSystemBody(text) : text
        }
        switch kind {
        case .photo: return String(localized: "Photo")
        case .voice: return String(localized: "Voice message")
        case .video: return String(localized: "Video")
        default: return String(localized: "No text")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(preview).font(.subheadline).lineLimit(2)
            HStack(spacing: 6) {
                if let trailing {
                    Text(trailing)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text(Timestamps.relative(createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
