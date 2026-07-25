import Supabase
import SwiftUI

/// Read-only view for customer accounts: their projects, shared progress
/// photos, and the tasks made visible to them. RLS is the real gate — this
/// screen simply renders whatever the customer is allowed to select.
struct CustomerPortalView: View {
    @Environment(AppState.self) private var appState

    @State private var projects: [ProjectOverview] = []

    var body: some View {
        List {
            Section {
                ForEach(projects, id: \.id) { project in
                    if let id = project.id {
                        NavigationLink {
                            CustomerProjectView(
                                projectId: id,
                                title: project.name ?? String(localized: "Your project")
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name ?? String(localized: "Your project"))
                                    .font(.headline)
                                if let address = project.address {
                                    Text(address)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let status = project.status {
                                    StatusPill(text: status.label, color: status.color)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } header: {
                Text("Your projects")
            } footer: {
                if projects.isEmpty {
                    Text("Your contractor will add you to a project soon.")
                }
            }

            Section {
                Button("Sign out", role: .destructive) {
                    Task { await appState.signOut() }
                }
            }
        }
        .navigationTitle("Ventline")
        .task {
            projects = (try? await ProjectRepo.overview()) ?? []
        }
        .refreshable {
            projects = (try? await ProjectRepo.overview()) ?? []
        }
    }
}

struct CustomerProjectView: View {
    let projectId: UUID
    let title: String

    @State private var tasks: [JobTask] = []
    @State private var messages: [Message] = []
    @State private var attachmentsByMessage: [UUID: [Attachment]] = [:]

    var body: some View {
        List {
            if !tasks.isEmpty {
                Section("Progress") {
                    ForEach(tasks, id: \.id) { task in
                        HStack(spacing: 10) {
                            Image(systemName: task.status == .approved || task.status == .done
                                ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.status == .approved || task.status == .done
                                    ? .green : .secondary)
                            Text(task.title)
                        }
                    }
                }
            }

            Section("Updates from the team") {
                if messages.isEmpty {
                    Text("No shared updates yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(messages, id: \.id) { message in
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(attachmentsByMessage[message.id] ?? [], id: \.id) { attachment in
                            if attachment.kind == .photo {
                                StorageImage(bucket: attachment.storageBucket, path: attachment.storagePath)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        if let body = message.body, !body.isEmpty {
                            Text(body)
                        }
                        Text(Timestamps.relative(message.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        // RLS filters to visible_to_customer tasks and shared messages.
        tasks = (try? await TaskRepo.tasks(projectId: projectId)) ?? []
        do {
            // Across all threads of the project (task chats included) —
            // RLS already narrows this to messages shared with the customer.
            let newestFirst: [Message] = try await Supa.client
                .from("messages")
                .select()
                .eq("project_id", value: projectId)
                .neq("kind", value: "system")
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            messages = newestFirst
            let attachments = try await MessageRepo.attachments(messageIds: newestFirst.map(\.id))
            attachmentsByMessage = Dictionary(grouping: attachments, by: \.messageId)
        } catch {
            // Pull-to-refresh retries.
        }
    }
}
