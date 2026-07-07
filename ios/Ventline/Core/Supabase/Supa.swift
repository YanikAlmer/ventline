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
