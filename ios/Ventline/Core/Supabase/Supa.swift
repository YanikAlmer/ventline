import Foundation
import Supabase

/// Shared Supabase client. Credentials come from Info.plist, which is filled
/// from Config/Secrets.xcconfig at build time.
enum Supa {
    static let client: SupabaseClient = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString),
            let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
            !key.isEmpty, key != "YOUR-ANON-KEY"
        else {
            fatalError("Missing Supabase credentials. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig and fill in your project URL and anon key.")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    /// Where a customer-facing magic link points. This is the *web* app, not
    /// the API — the customer opens it in a browser with no account.
    ///
    /// Falls back to localhost so the flow is exercisable before a domain
    /// exists; set `VentlineSiteURL` in Secrets.xcconfig for anything shared.
    static var publicSiteURL: String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "VentlineSiteURL") as? String
        let trimmed = configured?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !trimmed.isEmpty, trimmed != "YOUR-SITE-URL" else {
            return "http://localhost:3000"
        }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }
}

// Convenient aliases for the generated models.
typealias AppRole = PublicSchema.AppRole
typealias ProjectStatus = PublicSchema.ProjectStatus
typealias TaskStatus = PublicSchema.TaskStatus
typealias MessageKind = PublicSchema.MessageKind
typealias AttachmentKind = PublicSchema.AttachmentKind
typealias Company = PublicSchema.CompaniesSelect
typealias Profile = PublicSchema.ProfilesSelect
typealias Invite = PublicSchema.InvitesSelect
typealias Project = PublicSchema.ProjectsSelect
typealias ProjectMember = PublicSchema.ProjectMembersSelect
typealias ProjectOverview = PublicSchema.ProjectOverviewSelect
typealias JobTask = PublicSchema.TasksSelect
typealias TaskAssignment = PublicSchema.TaskAssignmentsSelect
typealias Message = PublicSchema.MessagesSelect
typealias Attachment = PublicSchema.AttachmentsSelect
typealias PhotoAnnotation = PublicSchema.PhotoAnnotationsSelect
typealias MessageMention = PublicSchema.MessageMentionsSelect
typealias MessageRef = PublicSchema.MessageRefsSelect

// Rapport loop.
typealias TimeEntry = PublicSchema.TimeEntriesSelect
typealias TimeEntryKind = PublicSchema.TimeEntryKind
typealias MaterialLine = PublicSchema.MaterialLinesSelect
typealias Report = PublicSchema.ReportsSelect
typealias ReportStatus = PublicSchema.ReportStatus
typealias ReportTimeLine = PublicSchema.ReportTimeLinesSelect
typealias ReportMaterialLine = PublicSchema.ReportMaterialLinesSelect
typealias Customer = PublicSchema.CustomersSelect
typealias CompanyBillingSettings = PublicSchema.CompanyBillingSettingsSelect
