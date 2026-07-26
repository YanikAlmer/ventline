import Foundation
import Supabase

/// One row of the cross-project conversation overview.
///
/// The shape mirrors the `inbox_page` RPC. It is declared here rather than in
/// GeneratedModels because the generator only emits table types, not function
/// return types.
struct InboxThread: Codable, Hashable, Sendable, Identifiable {
    let threadId: UUID
    let projectId: UUID
    let projectName: String
    let taskId: UUID?
    let taskTitle: String?
    let lastMessageId: UUID?
    let lastMessageAt: String?
    let lastSenderId: UUID?
    let lastSenderName: String?
    let lastKind: MessageKind?
    let lastPreview: String?
    let unreadCount: Int
    let unreadMentionCount: Int
    let muted: Bool

    var id: UUID { threadId }

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case projectId = "project_id"
        case projectName = "project_name"
        case taskId = "task_id"
        case taskTitle = "task_title"
        case lastMessageId = "last_message_id"
        case lastMessageAt = "last_message_at"
        case lastSenderId = "last_sender_id"
        case lastSenderName = "last_sender_name"
        case lastKind = "last_kind"
        case lastPreview = "last_preview"
        case unreadCount = "unread_count"
        case unreadMentionCount = "unread_mention_count"
        case muted = "muted"
    }
}

struct AttentionItem: Codable, Hashable, Sendable, Identifiable {
    let reason: String
    let messageId: UUID
    let threadId: UUID
    let projectId: UUID
    let taskId: UUID?
    let senderId: UUID?
    let kind: MessageKind?
    let body: String?
    let createdAt: String

    var id: UUID { messageId }
    var isMention: Bool { reason == "mention" }

    enum CodingKeys: String, CodingKey {
        case reason = "reason"
        case messageId = "message_id"
        case threadId = "thread_id"
        case projectId = "project_id"
        case taskId = "task_id"
        case senderId = "sender_id"
        case kind = "kind"
        case body = "body"
        case createdAt = "created_at"
    }
}

/// Conversations grouped by project, which is how the overview renders: a flat
/// list stops being usable as soon as a crew works across several sites.
struct ProjectThreadGroup: Identifiable, Hashable {
    let projectId: UUID
    let projectName: String
    var projectThread: InboxThread?
    var taskThreads: [InboxThread]

    var id: UUID { projectId }
    var unreadCount: Int {
        (projectThread?.unreadCount ?? 0) + taskThreads.reduce(0) { $0 + $1.unreadCount }
    }
    var mentionCount: Int {
        (projectThread?.unreadMentionCount ?? 0)
            + taskThreads.reduce(0) { $0 + $1.unreadMentionCount }
    }
    var lastMessageAt: String? {
        ([projectThread?.lastMessageAt] + taskThreads.map(\.lastMessageAt))
            .compactMap { $0 }
            .max()
    }
}

enum InboxRepo {
    static func threads() async throws -> [InboxThread] {
        try await Supa.client
            .rpc("inbox_page")
            .execute()
            .value
    }

    static func attention() async throws -> [AttentionItem] {
        try await Supa.client
            .rpc("inbox_attention")
            .execute()
            .value
    }

    /// Clears the unread badge and acknowledges any mentions in the thread.
    static func markRead(threadId: UUID) async throws {
        // CodingKeys are not optional decoration. supabase-swift's default
        // encoder sets only a date strategy — it does NOT convert to
        // snake_case — so a bare `pThreadId` reaches PostgREST as "pThreadId",
        // matches no overload of the function, and the call fails. Three RPCs
        // in this file were doing exactly that, silently, because their
        // callers used `try?`.
        struct Params: Encodable {
            let pThreadId: UUID
            enum CodingKeys: String, CodingKey { case pThreadId = "p_thread_id" }
        }
        try await Supa.client
            .rpc("mark_thread_read", params: Params(pThreadId: threadId))
            .execute()
    }

    static func personMessages(
        profileId: UUID,
        projectId: UUID? = nil
    ) async throws -> [PersonMessage] {
        struct Params: Encodable {
            let pProfileId: UUID
            let pProjectId: UUID?
            enum CodingKeys: String, CodingKey {
                case pProfileId = "p_profile_id"
                case pProjectId = "p_project_id"
            }
        }
        return try await Supa.client
            .rpc("person_messages", params: Params(pProfileId: profileId, pProjectId: projectId))
            .execute()
            .value
    }

    static func search(query: String) async throws -> [SearchHit] {
        struct Params: Encodable {
            let pQuery: String
            enum CodingKeys: String, CodingKey { case pQuery = "p_query" }
        }
        return try await Supa.client
            .rpc("search_messages", params: Params(pQuery: query))
            .execute()
            .value
    }

    static func group(_ threads: [InboxThread]) -> [ProjectThreadGroup] {
        var groups: [UUID: ProjectThreadGroup] = [:]
        var order: [UUID] = []

        for thread in threads {
            if groups[thread.projectId] == nil {
                groups[thread.projectId] = ProjectThreadGroup(
                    projectId: thread.projectId,
                    projectName: thread.projectName,
                    projectThread: nil,
                    taskThreads: []
                )
                order.append(thread.projectId)
            }
            if thread.taskId == nil {
                groups[thread.projectId]?.projectThread = thread
            } else {
                groups[thread.projectId]?.taskThreads.append(thread)
            }
        }

        return order
            .compactMap { groups[$0] }
            .sorted { ($0.lastMessageAt ?? "") > ($1.lastMessageAt ?? "") }
    }
}

struct PersonMessage: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let projectId: UUID
    let taskId: UUID?
    let threadId: UUID
    let senderId: UUID
    let kind: MessageKind?
    let body: String?
    let createdAt: String
    let hasPhoto: Bool
    let hasVoice: Bool
    let direction: String

    var isFrom: Bool { direction == "from" }

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case projectId = "project_id"
        case taskId = "task_id"
        case threadId = "thread_id"
        case senderId = "sender_id"
        case kind = "kind"
        case body = "body"
        case createdAt = "created_at"
        case hasPhoto = "has_photo"
        case hasVoice = "has_voice"
        case direction = "direction"
    }
}

struct SearchHit: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let projectId: UUID
    let taskId: UUID?
    let threadId: UUID
    let senderId: UUID
    let kind: MessageKind?
    let body: String?
    let createdAt: String
    let hasPhoto: Bool
    let hasVoice: Bool

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case projectId = "project_id"
        case taskId = "task_id"
        case threadId = "thread_id"
        case senderId = "sender_id"
        case kind = "kind"
        case body = "body"
        case createdAt = "created_at"
        case hasPhoto = "has_photo"
        case hasVoice = "has_voice"
    }
}
