import Foundation
import Supabase

// Data access layer. Every call goes through RLS — the server decides what
// each role may see or change; these functions just phrase the requests.

enum ProjectRepo {
    static func overview() async throws -> [ProjectOverview] {
        try await Supa.client
            .from("project_overview")
            .select()
            .order("last_activity_at", ascending: false, nullsFirst: false)
            .execute()
            .value
    }

    static func project(id: UUID) async throws -> Project {
        try await Supa.client
            .from("projects")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    static func create(name: String, address: String?, description: String?, companyId: UUID) async throws {
        let row = PublicSchema.ProjectsInsert(
            address: address,
            billingMode: nil,
            companyId: companyId,
            coverPhotoPath: nil,
            createdAt: nil,
            createdBy: nil,
            customerDisplayName: nil,
            customerId: nil,
            description: description,
            id: nil,
            name: name,
            status: nil,
            updatedAt: nil
        )
        try await Supa.client.from("projects").insert(row).execute()
    }

    static func setStatus(projectId: UUID, status: ProjectStatus) async throws {
        try await Supa.client
            .from("projects")
            .update(["status": status.rawValue])
            .eq("id", value: projectId)
            .execute()
    }

    static func members(projectId: UUID) async throws -> [ProjectMember] {
        try await Supa.client
            .from("project_members")
            .select()
            .eq("project_id", value: projectId)
            .execute()
            .value
    }

    static func addMember(projectId: UUID, profileId: UUID) async throws {
        let row = PublicSchema.ProjectMembersInsert(
            addedBy: nil, createdAt: nil, profileId: profileId, projectId: projectId
        )
        try await Supa.client.from("project_members").insert(row).execute()
    }

    static func removeMember(projectId: UUID, profileId: UUID) async throws {
        try await Supa.client
            .from("project_members")
            .delete()
            .eq("project_id", value: projectId)
            .eq("profile_id", value: profileId)
            .execute()
    }
}

enum TaskRepo {
    static func tasks(projectId: UUID) async throws -> [JobTask] {
        try await Supa.client
            .from("tasks")
            .select()
            .eq("project_id", value: projectId)
            .order("sort_order")
            .order("created_at")
            .execute()
            .value
    }

    static func task(id: UUID) async throws -> JobTask {
        try await Supa.client
            .from("tasks")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    static func myTasks(userId: UUID) async throws -> [JobTask] {
        let assignments: [TaskAssignment] = try await Supa.client
            .from("task_assignments")
            .select()
            .eq("profile_id", value: userId)
            .execute()
            .value
        let ids = assignments.map(\.taskId)
        if ids.isEmpty { return [] }
        return try await Supa.client
            .from("tasks")
            .select()
            .in("id", values: ids.map { $0 as any PostgrestFilterValue })
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func tasks(ids: [UUID]) async throws -> [JobTask] {
        if ids.isEmpty { return [] }
        return try await Supa.client
            .from("tasks")
            .select()
            .in("id", values: ids.map { $0 as any PostgrestFilterValue })
            .execute()
            .value
    }

    /// Steps of a work package, in board order.
    static func steps(parentId: UUID) async throws -> [JobTask] {
        try await Supa.client
            .from("tasks")
            .select()
            .eq("parent_id", value: parentId)
            .order("sort_order")
            .order("created_at")
            .execute()
            .value
    }

    /// Creates an Arbeitspaket, or an Arbeitsschritt when `parentId` is set.
    static func create(
        projectId: UUID, companyId: UUID, title: String, description: String?,
        dueDate: String?, dueTime: String?, parentId: UUID?, visibleToCustomer: Bool
    ) async throws -> JobTask {
        let row = PublicSchema.TasksInsert(
            approvedAt: nil, approvedBy: nil,
            companyId: companyId,
            completedAt: nil, completedBy: nil,
            createdAt: nil, createdBy: nil,
            description: description,
            dueDate: dueDate,
            // The database rejects a time without a date; never send one.
            dueTime: dueDate == nil ? nil : dueTime,
            id: nil,
            parentId: parentId,
            projectId: projectId,
            sortOrder: nil,
            status: nil,
            title: title,
            updatedAt: nil,
            visibleToCustomer: visibleToCustomer
        )
        return try await Supa.client
            .from("tasks")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }

    static func setStatus(taskId: UUID, status: TaskStatus) async throws {
        try await Supa.client
            .from("tasks")
            .update(["status": status.rawValue])
            .eq("id", value: taskId)
            .execute()
    }

    static func setCustomerVisibility(taskId: UUID, visible: Bool) async throws {
        try await Supa.client
            .from("tasks")
            .update(["visible_to_customer": visible])
            .eq("id", value: taskId)
            .execute()
    }

    static func assignments(taskId: UUID) async throws -> [TaskAssignment] {
        try await Supa.client
            .from("task_assignments")
            .select()
            .eq("task_id", value: taskId)
            .execute()
            .value
    }

    static func assign(taskId: UUID, profileId: UUID) async throws {
        let row = PublicSchema.TaskAssignmentsInsert(
            assignedBy: nil, createdAt: nil, profileId: profileId, taskId: taskId
        )
        try await Supa.client.from("task_assignments").insert(row).execute()
    }

    static func unassign(taskId: UUID, profileId: UUID) async throws {
        try await Supa.client
            .from("task_assignments")
            .delete()
            .eq("task_id", value: taskId)
            .eq("profile_id", value: profileId)
            .execute()
    }

    // MARK: - Files attached to the work itself

    static func attachments(taskId: UUID) async throws -> [Attachment] {
        try await Supa.client
            .from("attachments")
            .select()
            .eq("task_id", value: taskId)
            .order("created_at")
            .execute()
            .value
    }

    static func addAttachment(taskId: UUID, media: MediaUploader.Uploaded) async throws -> Attachment {
        let row = PublicSchema.AttachmentsInsert(
            byteSize: Int64(media.byteSize),
            caption: nil,
            createdAt: nil,
            durationSeconds: media.durationSeconds,
            height: media.height.map(Int32.init),
            id: nil,
            kind: media.attachmentKind,
            messageId: nil,
            mimeType: media.mimeType,
            reportId: nil,
            storageBucket: media.bucket,
            storagePath: media.path,
            taskId: taskId,
            // Server-stamped from the session; anything sent here is ignored.
            uploadedBy: nil,
            waveform: nil,
            width: media.width.map(Int32.init)
        )
        return try await Supa.client
            .from("attachments")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }

    /// Returns false when RLS refused the delete. A forbidden delete is not an
    /// error over PostgREST — it simply matches no rows — so the caller must
    /// not assume success and drop the file from the list.
    static func deleteAttachment(id: UUID) async throws -> Bool {
        let deleted: [Attachment] = try await Supa.client
            .from("attachments")
            .delete()
            .eq("id", value: id)
            .select()
            .execute()
            .value
        return !deleted.isEmpty
    }
}

enum PeopleRepo {
    static func companyMembers() async throws -> [Profile] {
        try await Supa.client
            .from("profiles")
            .select()
            .order("full_name")
            .execute()
            .value
    }

    static func setRole(profileId: UUID, role: AppRole) async throws {
        try await Supa.client
            .from("profiles")
            .update(["role": role.rawValue])
            .eq("id", value: profileId)
            .execute()
    }

    static func updateProfile(profileId: UUID, fullName: String, phone: String?) async throws {
        try await Supa.client
            .from("profiles")
            .update(["full_name": fullName, "phone": phone])
            .eq("id", value: profileId)
            .execute()
    }

    struct InviteResult: Decodable {
        let inviteId: UUID
        let code: String

        enum CodingKeys: String, CodingKey {
            case inviteId = "invite_id"
            case code
        }
    }

    static func createInvite(role: AppRole, fullName: String?, projectIds: [UUID]) async throws -> InviteResult {
        struct Params: Encodable {
            let pRole: String
            let pFullName: String?
            let pProjectIds: [UUID]

            enum CodingKeys: String, CodingKey {
                case pRole = "p_role"
                case pFullName = "p_full_name"
                case pProjectIds = "p_project_ids"
            }
        }
        let results: [InviteResult] = try await Supa.client
            .rpc("create_invite", params: Params(pRole: role.rawValue, pFullName: fullName, pProjectIds: projectIds))
            .execute()
            .value
        guard let result = results.first else {
            throw NSError(domain: "Ventline", code: 1, userInfo: [NSLocalizedDescriptionKey: "No invite returned"])
        }
        return result
    }

    static func openInvites() async throws -> [Invite] {
        try await Supa.client
            .from("invites")
            .select()
            .is("redeemed_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func revokeInvite(id: UUID) async throws {
        try await Supa.client
            .from("invites")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

enum OnboardingRepo {
    static func createCompany(name: String, fullName: String) async throws {
        struct Params: Encodable {
            let pName: String
            let pFullName: String

            enum CodingKeys: String, CodingKey {
                case pName = "p_name"
                case pFullName = "p_full_name"
            }
        }
        try await Supa.client
            .rpc("create_company", params: Params(pName: name, pFullName: fullName))
            .execute()
    }

    static func redeemInvite(code: String, fullName: String) async throws -> Bool {
        struct Params: Encodable {
            let pCode: String
            let pFullName: String

            enum CodingKeys: String, CodingKey {
                case pCode = "p_code"
                case pFullName = "p_full_name"
            }
        }
        return try await Supa.client
            .rpc("redeem_invite", params: Params(pCode: code, pFullName: fullName))
            .execute()
            .value
    }
}
