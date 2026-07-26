import Foundation
import Supabase

enum MessageRepo {
    static let pageSize = 50

    /// One page of a thread, oldest→newest. Pass `before` (a created_at
    /// timestamp) to page further back.
    static func page(projectId: UUID, taskId: UUID?, before: String? = nil) async throws -> [Message] {
        var query = Supa.client
            .from("messages")
            .select()
            .eq("project_id", value: projectId)

        if let taskId {
            query = query.eq("task_id", value: taskId)
        } else {
            query = query.is("task_id", value: nil)
        }
        if let before {
            query = query.lt("created_at", value: before)
        }

        let newestFirst: [Message] = try await query
            .order("created_at", ascending: false)
            .limit(pageSize)
            .execute()
            .value
        return newestFirst.reversed()
    }

    static func message(id: UUID) async throws -> Message {
        try await Supa.client
            .from("messages")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    static func attachments(messageIds: [UUID]) async throws -> [Attachment] {
        if messageIds.isEmpty { return [] }
        return try await Supa.client
            .from("attachments")
            .select()
            .in("message_id", values: messageIds.map { $0 as any PostgrestFilterValue })
            .execute()
            .value
    }

    static func annotations(attachmentIds: [UUID]) async throws -> [PhotoAnnotation] {
        if attachmentIds.isEmpty { return [] }
        return try await Supa.client
            .from("photo_annotations")
            .select()
            .in("attachment_id", values: attachmentIds.map { $0 as any PostgrestFilterValue })
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Atomic message + attachments insert via the send_message RPC.
    /// Returns the new message id.
    static func send(
        projectId: UUID,
        taskId: UUID?,
        kind: MessageKind,
        body: String?,
        attachments: [[String: AnyJSON]] = [],
        sharedWithCustomer: Bool = false,
        mentions: [[String: AnyEncodableJSON]] = [],
        refs: [[String: AnyEncodableJSON]] = []
    ) async throws -> UUID {
        struct Params: Encodable {
            let pProjectId: UUID
            let pTaskId: UUID?
            let pKind: String
            let pBody: String?
            let pAttachments: [[String: AnyJSON]]
            let pSharedWithCustomer: Bool
            let pMentions: [[String: AnyEncodableJSON]]
            let pRefs: [[String: AnyEncodableJSON]]

            enum CodingKeys: String, CodingKey {
                case pProjectId = "p_project_id"
                case pTaskId = "p_task_id"
                case pKind = "p_kind"
                case pBody = "p_body"
                case pAttachments = "p_attachments"
                case pSharedWithCustomer = "p_shared_with_customer"
                case pMentions = "p_mentions"
                case pRefs = "p_refs"
            }
        }
        return try await Supa.client
            .rpc("send_message", params: Params(
                pProjectId: projectId,
                pTaskId: taskId,
                pKind: kind.rawValue,
                pBody: body,
                pAttachments: attachments,
                pSharedWithCustomer: sharedWithCustomer,
                pMentions: mentions,
                pRefs: refs
            ))
            .execute()
            .value
    }

    // MARK: - Mentions and references

    /// Rows for a page of messages, so a thread renders its highlights without
    /// one request per bubble.
    static func mentions(messageIds: [UUID]) async throws -> [MessageMention] {
        if messageIds.isEmpty { return [] }
        return try await Supa.client
            .from("message_mentions")
            .select()
            .in("message_id", values: messageIds.map { $0 as any PostgrestFilterValue })
            .execute()
            .value
    }

    static func refs(messageIds: [UUID]) async throws -> [MessageRef] {
        if messageIds.isEmpty { return [] }
        return try await Supa.client
            .from("message_refs")
            .select()
            .in("message_id", values: messageIds.map { $0 as any PostgrestFilterValue })
            .execute()
            .value
    }

    struct MentionCandidate: Decodable, Identifiable, Hashable {
        let profileId: UUID
        let fullName: String
        let isMember: Bool

        var id: UUID { profileId }

        enum CodingKeys: String, CodingKey {
            case profileId = "profile_id"
            case fullName = "full_name"
            case isMember = "is_member"
        }
    }

    struct TaskRefCandidate: Decodable, Identifiable, Hashable {
        let taskId: UUID
        let title: String
        let parentTitle: String?

        var id: UUID { taskId }

        enum CodingKeys: String, CodingKey {
            case taskId = "task_id"
            case title
            case parentTitle = "parent_title"
        }
    }

    /// Mirrors app.can_mention server-side, so the picker offers exactly what
    /// the insert will accept — including office roles, who may be mentioned on
    /// any project without being members of it.
    static func mentionCandidates(
        projectId: UUID, query: String
    ) async throws -> [MentionCandidate] {
        struct Params: Encodable {
            let pProjectId: UUID
            let pQuery: String
            enum CodingKeys: String, CodingKey {
                case pProjectId = "p_project_id"
                case pQuery = "p_query"
            }
        }
        return try await Supa.client
            .rpc("mention_candidates", params: Params(pProjectId: projectId, pQuery: query))
            .execute()
            .value
    }

    static func taskRefCandidates(
        projectId: UUID, query: String
    ) async throws -> [TaskRefCandidate] {
        struct Params: Encodable {
            let pProjectId: UUID
            let pQuery: String
            enum CodingKeys: String, CodingKey {
                case pProjectId = "p_project_id"
                case pQuery = "p_query"
            }
        }
        return try await Supa.client
            .rpc("task_ref_candidates", params: Params(pProjectId: projectId, pQuery: query))
            .execute()
            .value
    }

    /// Soft delete (sender or office; the database enforces it).
    static func delete(messageId: UUID) async throws {
        struct Params: Encodable {
            let pMessageId: UUID

            enum CodingKeys: String, CodingKey {
                case pMessageId = "p_message_id"
            }
        }
        try await Supa.client
            .rpc("delete_message", params: Params(pMessageId: messageId))
            .execute()
    }

    static func saveAnnotation(
        attachmentId: UUID,
        authorId: UUID,
        drawingData: [String: AnyJSON],
        renderedPath: String
    ) async throws {
        struct Row: Encodable {
            let attachmentId: UUID
            let authorId: UUID
            let drawingData: [String: AnyJSON]
            let renderedPath: String

            enum CodingKeys: String, CodingKey {
                case attachmentId = "attachment_id"
                case authorId = "author_id"
                case drawingData = "drawing_data"
                case renderedPath = "rendered_path"
            }
        }
        try await Supa.client
            .from("photo_annotations")
            .insert(Row(
                attachmentId: attachmentId, authorId: authorId,
                drawingData: drawingData, renderedPath: renderedPath
            ))
            .execute()
    }
}
