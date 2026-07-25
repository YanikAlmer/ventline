import Foundation
import Supabase

// The Rapport loop: recording time and materials on site, assembling them into
// a report, and getting it signed.
//
// Every scope column (company_id, work_date, recorded_by) is derived by a
// database trigger. The generated Insert structs still demand them because the
// columns are NOT NULL, so a placeholder goes in and the trigger overwrites it
// before any constraint or policy sees the row — the same pattern send_message
// already uses for company_id.

enum TimeRepo {
    /// A placeholder for a trigger-derived NOT NULL column.
    private static let derived = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    /// The entry whose clock is still running, if any. The database allows at
    /// most one per person, so this is either empty or a single row.
    static func openEntry(profileId: UUID) async throws -> TimeEntry? {
        let rows: [TimeEntry] = try await Supa.client
            .from("time_entries")
            .select()
            .eq("profile_id", value: profileId)
            .is("ended_at", value: nil)
            .is("voided_at", value: nil)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func entries(projectId: UUID, limit: Int = 200) async throws -> [TimeEntry] {
        try await Supa.client
            .from("time_entries")
            .select()
            .eq("project_id", value: projectId)
            .is("voided_at", value: nil)
            .order("work_date", ascending: false)
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func myEntries(profileId: UUID, limit: Int = 100) async throws -> [TimeEntry] {
        try await Supa.client
            .from("time_entries")
            .select()
            .eq("profile_id", value: profileId)
            .is("voided_at", value: nil)
            .order("work_date", ascending: false)
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func start(
        projectId: UUID, profileId: UUID, taskId: UUID?, kind: TimeEntryKind = .work
    ) async throws -> TimeEntry {
        let now = Date()
        let row = PublicSchema.TimeEntriesInsert(
            breakMinutes: 0,
            companyId: derived,
            createdAt: nil,
            endedAt: nil,
            id: nil,
            kind: kind,
            note: nil,
            profileId: profileId,
            projectId: projectId,
            recordedBy: nil,
            revision: nil,
            startedAt: iso(now),
            taskId: taskId,
            updatedAt: nil,
            voidedAt: nil,
            voidedReason: nil,
            workDate: isoDay.string(from: now),
            workedMinutes: nil
        )
        return try await Supa.client
            .from("time_entries").insert(row).select().single().execute().value
    }

    static func stop(entryId: UUID, breakMinutes: Int, note: String?) async throws {
        struct Patch: Encodable {
            let endedAt: String
            let breakMinutes: Int
            let note: String?
            enum CodingKeys: String, CodingKey {
                case endedAt = "ended_at"
                case breakMinutes = "break_minutes"
                case note
            }
        }
        try await Supa.client
            .from("time_entries")
            .update(Patch(endedAt: iso(Date()), breakMinutes: breakMinutes,
                          note: note?.isEmpty == true ? nil : note))
            .eq("id", value: entryId)
            .execute()
    }

    /// A whole shift entered after the fact — the common case when somebody
    /// forgot to start the clock.
    static func logManual(
        projectId: UUID, profileId: UUID, taskId: UUID?,
        start: Date, end: Date, breakMinutes: Int, note: String?,
        kind: TimeEntryKind = .work
    ) async throws -> TimeEntry {
        let row = PublicSchema.TimeEntriesInsert(
            breakMinutes: Int32(breakMinutes),
            companyId: derived,
            createdAt: nil,
            endedAt: iso(end),
            id: nil,
            kind: kind,
            note: note?.isEmpty == true ? nil : note,
            profileId: profileId,
            projectId: projectId,
            recordedBy: nil,
            revision: nil,
            startedAt: iso(start),
            taskId: taskId,
            updatedAt: nil,
            voidedAt: nil,
            voidedReason: nil,
            workDate: isoDay.string(from: start),
            workedMinutes: nil
        )
        return try await Supa.client
            .from("time_entries").insert(row).select().single().execute().value
    }

    /// Corrections carry a reason, which the append-only log records. The
    /// reason is set for the transaction, so it must be sent immediately
    /// before the update it explains.
    static func setCorrectionReason(_ reason: String) async throws {
        struct Params: Encodable {
            let pReason: String
            enum CodingKeys: String, CodingKey { case pReason = "p_reason" }
        }
        try await Supa.client
            .rpc("set_correction_reason", params: Params(pReason: reason))
            .execute()
    }

    static func void(entryId: UUID, reason: String) async throws {
        try await setCorrectionReason(reason)
        struct Patch: Encodable {
            let voidedAt: String
            let voidedReason: String
            enum CodingKeys: String, CodingKey {
                case voidedAt = "voided_at"
                case voidedReason = "voided_reason"
            }
        }
        try await Supa.client
            .from("time_entries")
            .update(Patch(voidedAt: ISO8601DateFormatter().string(from: Date()),
                          voidedReason: reason))
            .eq("id", value: entryId)
            .execute()
    }
}

enum MaterialRepo {
    private static let derived = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static func lines(projectId: UUID) async throws -> [MaterialLine] {
        try await Supa.client
            .from("material_lines")
            .select()
            .eq("project_id", value: projectId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func add(
        projectId: UUID, taskId: UUID?, description: String,
        quantityMilli: Int, unit: String, unitPriceRappen: Int
    ) async throws -> MaterialLine {
        let row = PublicSchema.MaterialLinesInsert(
            companyId: derived,
            createdAt: nil,
            description: description,
            id: nil,
            projectId: projectId,
            quantityMilli: Int64(quantityMilli),
            recordedBy: nil,
            taskId: taskId,
            unit: unit,
            unitPriceRappen: Int64(unitPriceRappen),
            updatedAt: nil
        )
        return try await Supa.client
            .from("material_lines").insert(row).select().single().execute().value
    }

    static func remove(id: UUID) async throws {
        try await Supa.client.from("material_lines").delete().eq("id", value: id).execute()
    }
}

enum RapportRepo {
    private static let derived = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static func reports(projectId: UUID) async throws -> [Report] {
        try await Supa.client
            .from("reports")
            .select()
            .eq("project_id", value: projectId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func report(id: UUID) async throws -> Report {
        try await Supa.client
            .from("reports").select().eq("id", value: id).single().execute().value
    }

    static func createDraft(projectId: UUID, title: String?, summary: String?) async throws -> Report {
        let row = PublicSchema.ReportsInsert(
            companyId: derived,
            contentHash: nil, correctsReportId: nil,
            createdAt: nil, createdBy: nil, customerId: nil,
            docType: nil, id: nil, number: nil, numberText: nil,
            pdfGeneratedAt: nil, pdfPath: nil, pdfSha256: nil,
            periodFrom: nil, periodKey: nil, periodTo: nil,
            projectId: projectId,
            sentAt: nil, signaturePath: nil, signedAt: nil, signerName: nil,
            snapshot: nil, status: nil, summary: summary, title: title,
            totalNetRappen: nil, updatedAt: nil
        )
        return try await Supa.client
            .from("reports").insert(row).select().single().execute().value
    }

    static func timeLines(reportId: UUID) async throws -> [ReportTimeLine] {
        try await Supa.client
            .from("report_time_lines")
            .select()
            .eq("report_id", value: reportId)
            .order("performed_on")
            .order("sort_order")
            .execute()
            .value
    }

    static func materialLines(reportId: UUID) async throws -> [ReportMaterialLine] {
        try await Supa.client
            .from("report_material_lines")
            .select()
            .eq("report_id", value: reportId)
            .order("sort_order")
            .execute()
            .value
    }

    /// Copies recorded time onto the draft server-side, so the minutes on the
    /// Rapport are the minutes that were recorded — a client cannot inflate a
    /// line and then have the customer sign it.
    @discardableResult
    static func attachTime(reportId: UUID, timeEntryIds: [UUID]) async throws -> Int {
        struct Params: Encodable {
            let pReportId: UUID
            let pTimeEntryIds: [UUID]
            enum CodingKeys: String, CodingKey {
                case pReportId = "p_report_id"
                case pTimeEntryIds = "p_time_entry_ids"
            }
        }
        return try await Supa.client
            .rpc("attach_time_to_report",
                 params: Params(pReportId: reportId, pTimeEntryIds: timeEntryIds))
            .execute()
            .value
    }

    static func addMaterialLine(
        reportId: UUID, sourceId: UUID?, description: String,
        quantityMilli: Int, unit: String, unitPriceRappen: Int, sortOrder: Int
    ) async throws {
        let row = PublicSchema.ReportMaterialLinesInsert(
            description: description,
            id: nil,
            materialLineId: sourceId,
            quantityMilli: Int64(quantityMilli),
            reportId: reportId,
            sortOrder: Int32(sortOrder),
            unit: unit,
            unitPriceRappen: Int64(unitPriceRappen)
        )
        try await Supa.client.from("report_material_lines").insert(row).execute()
    }

    /// Signing assigns the number, freezes the content and computes the hash —
    /// all server-side. The client cannot write any of those columns.
    static func sign(reportId: UUID, signerName: String, signaturePath: String?) async throws -> Report {
        struct Params: Encodable {
            let pReportId: UUID
            let pSignerName: String
            let pSignaturePath: String?
            enum CodingKeys: String, CodingKey {
                case pReportId = "p_report_id"
                case pSignerName = "p_signer_name"
                case pSignaturePath = "p_signature_path"
            }
        }
        return try await Supa.client
            .rpc("sign_report", params: Params(
                pReportId: reportId, pSignerName: signerName, pSignaturePath: signaturePath))
            .execute()
            .value
    }

    struct DocumentLink: Decodable {
        let linkId: UUID
        let token: String
        let expiresAt: String

        enum CodingKeys: String, CodingKey {
            case linkId = "link_id"
            case token
            case expiresAt = "expires_at"
        }
    }

    /// The plaintext token comes back exactly once and is not recoverable
    /// afterwards — losing it means issuing a new link.
    static func createLink(reportId: UUID, validDays: Int = 90) async throws -> DocumentLink {
        struct Params: Encodable {
            let pKind: String
            let pDocumentId: UUID
            let pValidDays: Int
            enum CodingKeys: String, CodingKey {
                case pKind = "p_kind"
                case pDocumentId = "p_document_id"
                case pValidDays = "p_valid_days"
            }
        }
        let rows: [DocumentLink] = try await Supa.client
            .rpc("create_document_link",
                 params: Params(pKind: "report", pDocumentId: reportId, pValidDays: validDays))
            .execute()
            .value
        guard let link = rows.first else {
            throw NSError(domain: "Ventline", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "No link returned"])
        }
        return link
    }

    /// Uploads the captured signature into the private signatures bucket. The
    /// path convention matches every other bucket: {company}/{project}/...
    static func uploadSignature(
        png: Data, companyId: UUID, projectId: UUID
    ) async throws -> String {
        let path = "\(companyId.uuidString.lowercased())/\(projectId.uuidString.lowercased())/"
            + "\(UUID().uuidString.lowercased()).png"
        try await Supa.client.storage.from("signatures").upload(
            path, data: png, options: FileOptions(contentType: "image/png")
        )
        return path
    }
}
