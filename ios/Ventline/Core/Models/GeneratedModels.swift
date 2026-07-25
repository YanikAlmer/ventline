import Foundation
import Supabase

public enum PublicSchema {
  public enum AppRole: String, Codable, Hashable, Sendable {
    case owner = "owner"
    case manager = "manager"
    case foreman = "foreman"
    case worker = "worker"
    case customer = "customer"
  }
  public enum AttachmentKind: String, Codable, Hashable, Sendable {
    case photo = "photo"
    case voice = "voice"
    case video = "video"
  }
  public enum DevicePlatform: String, Codable, Hashable, Sendable {
    case ios = "ios"
    case web = "web"
  }
  public enum MessageKind: String, Codable, Hashable, Sendable {
    case text = "text"
    case photo = "photo"
    case voice = "voice"
    case video = "video"
    case system = "system"
  }
  public enum MessageRefKind: String, Codable, Hashable, Sendable {
    case task = "task"
    case attachment = "attachment"
  }
  public enum ProjectStatus: String, Codable, Hashable, Sendable {
    case planning = "planning"
    case active = "active"
    case onHold = "on_hold"
    case completed = "completed"
    case archived = "archived"
  }
  public enum TaskStatus: String, Codable, Hashable, Sendable {
    case todo = "todo"
    case inProgress = "in_progress"
    case blocked = "blocked"
    case done = "done"
    case approved = "approved"
  }
  public struct AttachmentsSelect: Codable, Hashable, Sendable {
    public let byteSize: Int64?
    public let createdAt: String
    public let durationSeconds: Double?
    public let height: Int32?
    public let id: UUID
    public let kind: AttachmentKind
    public let messageId: UUID
    public let mimeType: String
    public let storageBucket: String
    public let storagePath: String
    public let waveform: AnyJSON?
    public let width: Int32?
    public enum CodingKeys: String, CodingKey {
      case byteSize = "byte_size"
      case createdAt = "created_at"
      case durationSeconds = "duration_seconds"
      case height = "height"
      case id = "id"
      case kind = "kind"
      case messageId = "message_id"
      case mimeType = "mime_type"
      case storageBucket = "storage_bucket"
      case storagePath = "storage_path"
      case waveform = "waveform"
      case width = "width"
    }
  }
  public struct AttachmentsInsert: Codable, Hashable, Sendable {
    public let byteSize: Int64?
    public let createdAt: String?
    public let durationSeconds: Double?
    public let height: Int32?
    public let id: UUID?
    public let kind: AttachmentKind
    public let messageId: UUID
    public let mimeType: String
    public let storageBucket: String
    public let storagePath: String
    public let waveform: AnyJSON?
    public let width: Int32?
    public enum CodingKeys: String, CodingKey {
      case byteSize = "byte_size"
      case createdAt = "created_at"
      case durationSeconds = "duration_seconds"
      case height = "height"
      case id = "id"
      case kind = "kind"
      case messageId = "message_id"
      case mimeType = "mime_type"
      case storageBucket = "storage_bucket"
      case storagePath = "storage_path"
      case waveform = "waveform"
      case width = "width"
    }
  }
  public struct AttachmentsUpdate: Codable, Hashable, Sendable {
    public let byteSize: Int64?
    public let createdAt: String?
    public let durationSeconds: Double?
    public let height: Int32?
    public let id: UUID?
    public let kind: AttachmentKind?
    public let messageId: UUID?
    public let mimeType: String?
    public let storageBucket: String?
    public let storagePath: String?
    public let waveform: AnyJSON?
    public let width: Int32?
    public enum CodingKeys: String, CodingKey {
      case byteSize = "byte_size"
      case createdAt = "created_at"
      case durationSeconds = "duration_seconds"
      case height = "height"
      case id = "id"
      case kind = "kind"
      case messageId = "message_id"
      case mimeType = "mime_type"
      case storageBucket = "storage_bucket"
      case storagePath = "storage_path"
      case waveform = "waveform"
      case width = "width"
    }
  }
  public struct CompaniesSelect: Codable, Hashable, Sendable {
    public let createdAt: String
    public let id: UUID
    public let name: String
    public enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case id = "id"
      case name = "name"
    }
  }
  public struct CompaniesInsert: Codable, Hashable, Sendable {
    public let createdAt: String?
    public let id: UUID?
    public let name: String
    public enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case id = "id"
      case name = "name"
    }
  }
  public struct CompaniesUpdate: Codable, Hashable, Sendable {
    public let createdAt: String?
    public let id: UUID?
    public let name: String?
    public enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case id = "id"
      case name = "name"
    }
  }
  public struct DevicesSelect: Codable, Hashable, Sendable {
    public let apnsToken: String
    public let id: UUID
    public let platform: DevicePlatform
    public let profileId: UUID
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case apnsToken = "apns_token"
      case id = "id"
      case platform = "platform"
      case profileId = "profile_id"
      case updatedAt = "updated_at"
    }
  }
  public struct DevicesInsert: Codable, Hashable, Sendable {
    public let apnsToken: String
    public let id: UUID?
    public let platform: DevicePlatform
    public let profileId: UUID
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case apnsToken = "apns_token"
      case id = "id"
      case platform = "platform"
      case profileId = "profile_id"
      case updatedAt = "updated_at"
    }
  }
  public struct DevicesUpdate: Codable, Hashable, Sendable {
    public let apnsToken: String?
    public let id: UUID?
    public let platform: DevicePlatform?
    public let profileId: UUID?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case apnsToken = "apns_token"
      case id = "id"
      case platform = "platform"
      case profileId = "profile_id"
      case updatedAt = "updated_at"
    }
  }
  public struct InvitesSelect: Codable, Hashable, Sendable {
    public let code: String
    public let companyId: UUID
    public let createdAt: String
    public let expiresAt: String
    public let fullName: String?
    public let id: UUID
    public let invitedBy: UUID?
    public let projectIds: [UUID]
    public let redeemedAt: String?
    public let redeemedBy: UUID?
    public let role: AppRole
    public enum CodingKeys: String, CodingKey {
      case code = "code"
      case companyId = "company_id"
      case createdAt = "created_at"
      case expiresAt = "expires_at"
      case fullName = "full_name"
      case id = "id"
      case invitedBy = "invited_by"
      case projectIds = "project_ids"
      case redeemedAt = "redeemed_at"
      case redeemedBy = "redeemed_by"
      case role = "role"
    }
  }
  public struct InvitesInsert: Codable, Hashable, Sendable {
    public let code: String
    public let companyId: UUID
    public let createdAt: String?
    public let expiresAt: String?
    public let fullName: String?
    public let id: UUID?
    public let invitedBy: UUID?
    public let projectIds: [UUID]?
    public let redeemedAt: String?
    public let redeemedBy: UUID?
    public let role: AppRole?
    public enum CodingKeys: String, CodingKey {
      case code = "code"
      case companyId = "company_id"
      case createdAt = "created_at"
      case expiresAt = "expires_at"
      case fullName = "full_name"
      case id = "id"
      case invitedBy = "invited_by"
      case projectIds = "project_ids"
      case redeemedAt = "redeemed_at"
      case redeemedBy = "redeemed_by"
      case role = "role"
    }
  }
  public struct InvitesUpdate: Codable, Hashable, Sendable {
    public let code: String?
    public let companyId: UUID?
    public let createdAt: String?
    public let expiresAt: String?
    public let fullName: String?
    public let id: UUID?
    public let invitedBy: UUID?
    public let projectIds: [UUID]?
    public let redeemedAt: String?
    public let redeemedBy: UUID?
    public let role: AppRole?
    public enum CodingKeys: String, CodingKey {
      case code = "code"
      case companyId = "company_id"
      case createdAt = "created_at"
      case expiresAt = "expires_at"
      case fullName = "full_name"
      case id = "id"
      case invitedBy = "invited_by"
      case projectIds = "project_ids"
      case redeemedAt = "redeemed_at"
      case redeemedBy = "redeemed_by"
      case role = "role"
    }
  }
  public struct MediaDeletionQueueSelect: Codable, Hashable, Sendable, Identifiable {
    public let enqueuedAt: String
    public let id: Int64
    public let storageBucket: String
    public let storagePath: String
    public enum CodingKeys: String, CodingKey {
      case enqueuedAt = "enqueued_at"
      case id = "id"
      case storageBucket = "storage_bucket"
      case storagePath = "storage_path"
    }
  }
  public struct MediaDeletionQueueInsert: Codable, Hashable, Sendable, Identifiable {
    public let enqueuedAt: String?
    public let id: Int64?
    public let storageBucket: String
    public let storagePath: String
    public enum CodingKeys: String, CodingKey {
      case enqueuedAt = "enqueued_at"
      case id = "id"
      case storageBucket = "storage_bucket"
      case storagePath = "storage_path"
    }
  }
  public struct MediaDeletionQueueUpdate: Codable, Hashable, Sendable, Identifiable {
    public let enqueuedAt: String?
    public let id: Int64?
    public let storageBucket: String?
    public let storagePath: String?
    public enum CodingKeys: String, CodingKey {
      case enqueuedAt = "enqueued_at"
      case id = "id"
      case storageBucket = "storage_bucket"
      case storagePath = "storage_path"
    }
  }
  public struct MessageMentionsSelect: Codable, Hashable, Sendable {
    public let acknowledgedAt: String?
    public let companyId: UUID
    public let createdAt: String
    public let length: Int32?
    public let mentionedProfileId: UUID
    public let messageId: UUID
    public let projectId: UUID
    public let startOffset: Int32?
    public enum CodingKeys: String, CodingKey {
      case acknowledgedAt = "acknowledged_at"
      case companyId = "company_id"
      case createdAt = "created_at"
      case length = "length"
      case mentionedProfileId = "mentioned_profile_id"
      case messageId = "message_id"
      case projectId = "project_id"
      case startOffset = "start_offset"
    }
  }
  public struct MessageMentionsInsert: Codable, Hashable, Sendable {
    public let acknowledgedAt: String?
    public let companyId: UUID
    public let createdAt: String?
    public let length: Int32?
    public let mentionedProfileId: UUID
    public let messageId: UUID
    public let projectId: UUID
    public let startOffset: Int32?
    public enum CodingKeys: String, CodingKey {
      case acknowledgedAt = "acknowledged_at"
      case companyId = "company_id"
      case createdAt = "created_at"
      case length = "length"
      case mentionedProfileId = "mentioned_profile_id"
      case messageId = "message_id"
      case projectId = "project_id"
      case startOffset = "start_offset"
    }
  }
  public struct MessageMentionsUpdate: Codable, Hashable, Sendable {
    public let acknowledgedAt: String?
    public let companyId: UUID?
    public let createdAt: String?
    public let length: Int32?
    public let mentionedProfileId: UUID?
    public let messageId: UUID?
    public let projectId: UUID?
    public let startOffset: Int32?
    public enum CodingKeys: String, CodingKey {
      case acknowledgedAt = "acknowledged_at"
      case companyId = "company_id"
      case createdAt = "created_at"
      case length = "length"
      case mentionedProfileId = "mentioned_profile_id"
      case messageId = "message_id"
      case projectId = "project_id"
      case startOffset = "start_offset"
    }
  }
  public struct MessageReadsSelect: Codable, Hashable, Sendable {
    public let messageId: UUID
    public let profileId: UUID
    public let readAt: String
    public enum CodingKeys: String, CodingKey {
      case messageId = "message_id"
      case profileId = "profile_id"
      case readAt = "read_at"
    }
  }
  public struct MessageReadsInsert: Codable, Hashable, Sendable {
    public let messageId: UUID
    public let profileId: UUID
    public let readAt: String?
    public enum CodingKeys: String, CodingKey {
      case messageId = "message_id"
      case profileId = "profile_id"
      case readAt = "read_at"
    }
  }
  public struct MessageReadsUpdate: Codable, Hashable, Sendable {
    public let messageId: UUID?
    public let profileId: UUID?
    public let readAt: String?
    public enum CodingKeys: String, CodingKey {
      case messageId = "message_id"
      case profileId = "profile_id"
      case readAt = "read_at"
    }
  }
  public struct MessageRefsSelect: Codable, Hashable, Sendable {
    public let attachmentId: UUID?
    public let companyId: UUID
    public let createdAt: String
    public let id: UUID
    public let kind: MessageRefKind
    public let length: Int32?
    public let messageId: UUID
    public let projectId: UUID
    public let startOffset: Int32?
    public let taskId: UUID?
    public enum CodingKeys: String, CodingKey {
      case attachmentId = "attachment_id"
      case companyId = "company_id"
      case createdAt = "created_at"
      case id = "id"
      case kind = "kind"
      case length = "length"
      case messageId = "message_id"
      case projectId = "project_id"
      case startOffset = "start_offset"
      case taskId = "task_id"
    }
  }
  public struct MessageRefsInsert: Codable, Hashable, Sendable {
    public let attachmentId: UUID?
    public let companyId: UUID
    public let createdAt: String?
    public let id: UUID?
    public let kind: MessageRefKind
    public let length: Int32?
    public let messageId: UUID
    public let projectId: UUID
    public let startOffset: Int32?
    public let taskId: UUID?
    public enum CodingKeys: String, CodingKey {
      case attachmentId = "attachment_id"
      case companyId = "company_id"
      case createdAt = "created_at"
      case id = "id"
      case kind = "kind"
      case length = "length"
      case messageId = "message_id"
      case projectId = "project_id"
      case startOffset = "start_offset"
      case taskId = "task_id"
    }
  }
  public struct MessageRefsUpdate: Codable, Hashable, Sendable {
    public let attachmentId: UUID?
    public let companyId: UUID?
    public let createdAt: String?
    public let id: UUID?
    public let kind: MessageRefKind?
    public let length: Int32?
    public let messageId: UUID?
    public let projectId: UUID?
    public let startOffset: Int32?
    public let taskId: UUID?
    public enum CodingKeys: String, CodingKey {
      case attachmentId = "attachment_id"
      case companyId = "company_id"
      case createdAt = "created_at"
      case id = "id"
      case kind = "kind"
      case length = "length"
      case messageId = "message_id"
      case projectId = "project_id"
      case startOffset = "start_offset"
      case taskId = "task_id"
    }
  }
  public struct MessagesSelect: Codable, Hashable, Sendable {
    public let body: String?
    public let companyId: UUID
    public let createdAt: String
    public let deletedAt: String?
    public let editedAt: String?
    public let expiresAt: String?
    public let hasPhoto: Bool
    public let hasVideo: Bool
    public let hasVoice: Bool
    public let id: UUID
    public let kind: MessageKind
    public let projectId: UUID
    public let replyToMessageId: UUID?
    public let searchTsv: TsvectorSelect?
    public let senderId: UUID
    public let sharedWithCustomer: Bool
    public let taskId: UUID?
    public let threadId: UUID?
    public enum CodingKeys: String, CodingKey {
      case body = "body"
      case companyId = "company_id"
      case createdAt = "created_at"
      case deletedAt = "deleted_at"
      case editedAt = "edited_at"
      case expiresAt = "expires_at"
      case hasPhoto = "has_photo"
      case hasVideo = "has_video"
      case hasVoice = "has_voice"
      case id = "id"
      case kind = "kind"
      case projectId = "project_id"
      case replyToMessageId = "reply_to_message_id"
      case searchTsv = "search_tsv"
      case senderId = "sender_id"
      case sharedWithCustomer = "shared_with_customer"
      case taskId = "task_id"
      case threadId = "thread_id"
    }
  }
  public struct MessagesInsert: Codable, Hashable, Sendable {
    public let body: String?
    public let companyId: UUID
    public let createdAt: String?
    public let deletedAt: String?
    public let editedAt: String?
    public let expiresAt: String?
    public let hasPhoto: Bool?
    public let hasVideo: Bool?
    public let hasVoice: Bool?
    public let id: UUID?
    public let kind: MessageKind?
    public let projectId: UUID
    public let replyToMessageId: UUID?
    public let searchTsv: TsvectorSelect?
    public let senderId: UUID
    public let sharedWithCustomer: Bool?
    public let taskId: UUID?
    public let threadId: UUID?
    public enum CodingKeys: String, CodingKey {
      case body = "body"
      case companyId = "company_id"
      case createdAt = "created_at"
      case deletedAt = "deleted_at"
      case editedAt = "edited_at"
      case expiresAt = "expires_at"
      case hasPhoto = "has_photo"
      case hasVideo = "has_video"
      case hasVoice = "has_voice"
      case id = "id"
      case kind = "kind"
      case projectId = "project_id"
      case replyToMessageId = "reply_to_message_id"
      case searchTsv = "search_tsv"
      case senderId = "sender_id"
      case sharedWithCustomer = "shared_with_customer"
      case taskId = "task_id"
      case threadId = "thread_id"
    }
  }
  public struct MessagesUpdate: Codable, Hashable, Sendable {
    public let body: String?
    public let companyId: UUID?
    public let createdAt: String?
    public let deletedAt: String?
    public let editedAt: String?
    public let expiresAt: String?
    public let hasPhoto: Bool?
    public let hasVideo: Bool?
    public let hasVoice: Bool?
    public let id: UUID?
    public let kind: MessageKind?
    public let projectId: UUID?
    public let replyToMessageId: UUID?
    public let searchTsv: TsvectorSelect?
    public let senderId: UUID?
    public let sharedWithCustomer: Bool?
    public let taskId: UUID?
    public let threadId: UUID?
    public enum CodingKeys: String, CodingKey {
      case body = "body"
      case companyId = "company_id"
      case createdAt = "created_at"
      case deletedAt = "deleted_at"
      case editedAt = "edited_at"
      case expiresAt = "expires_at"
      case hasPhoto = "has_photo"
      case hasVideo = "has_video"
      case hasVoice = "has_voice"
      case id = "id"
      case kind = "kind"
      case projectId = "project_id"
      case replyToMessageId = "reply_to_message_id"
      case searchTsv = "search_tsv"
      case senderId = "sender_id"
      case sharedWithCustomer = "shared_with_customer"
      case taskId = "task_id"
      case threadId = "thread_id"
    }
  }
  public struct PhotoAnnotationsSelect: Codable, Hashable, Sendable {
    public let attachmentId: UUID
    public let authorId: UUID
    public let createdAt: String
    public let drawingData: AnyJSON
    public let id: UUID
    public let renderedPath: String
    public enum CodingKeys: String, CodingKey {
      case attachmentId = "attachment_id"
      case authorId = "author_id"
      case createdAt = "created_at"
      case drawingData = "drawing_data"
      case id = "id"
      case renderedPath = "rendered_path"
    }
  }
  public struct PhotoAnnotationsInsert: Codable, Hashable, Sendable {
    public let attachmentId: UUID
    public let authorId: UUID
    public let createdAt: String?
    public let drawingData: AnyJSON
    public let id: UUID?
    public let renderedPath: String
    public enum CodingKeys: String, CodingKey {
      case attachmentId = "attachment_id"
      case authorId = "author_id"
      case createdAt = "created_at"
      case drawingData = "drawing_data"
      case id = "id"
      case renderedPath = "rendered_path"
    }
  }
  public struct PhotoAnnotationsUpdate: Codable, Hashable, Sendable {
    public let attachmentId: UUID?
    public let authorId: UUID?
    public let createdAt: String?
    public let drawingData: AnyJSON?
    public let id: UUID?
    public let renderedPath: String?
    public enum CodingKeys: String, CodingKey {
      case attachmentId = "attachment_id"
      case authorId = "author_id"
      case createdAt = "created_at"
      case drawingData = "drawing_data"
      case id = "id"
      case renderedPath = "rendered_path"
    }
  }
  public struct ProfilesSelect: Codable, Hashable, Sendable {
    public let avatarPath: String?
    public let companyId: UUID
    public let createdAt: String
    public let fullName: String
    public let id: UUID
    public let phone: String?
    public let role: AppRole
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case avatarPath = "avatar_path"
      case companyId = "company_id"
      case createdAt = "created_at"
      case fullName = "full_name"
      case id = "id"
      case phone = "phone"
      case role = "role"
      case updatedAt = "updated_at"
    }
  }
  public struct ProfilesInsert: Codable, Hashable, Sendable {
    public let avatarPath: String?
    public let companyId: UUID
    public let createdAt: String?
    public let fullName: String
    public let id: UUID
    public let phone: String?
    public let role: AppRole?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case avatarPath = "avatar_path"
      case companyId = "company_id"
      case createdAt = "created_at"
      case fullName = "full_name"
      case id = "id"
      case phone = "phone"
      case role = "role"
      case updatedAt = "updated_at"
    }
  }
  public struct ProfilesUpdate: Codable, Hashable, Sendable {
    public let avatarPath: String?
    public let companyId: UUID?
    public let createdAt: String?
    public let fullName: String?
    public let id: UUID?
    public let phone: String?
    public let role: AppRole?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case avatarPath = "avatar_path"
      case companyId = "company_id"
      case createdAt = "created_at"
      case fullName = "full_name"
      case id = "id"
      case phone = "phone"
      case role = "role"
      case updatedAt = "updated_at"
    }
  }
  public struct ProjectMembersSelect: Codable, Hashable, Sendable {
    public let addedBy: UUID?
    public let createdAt: String
    public let profileId: UUID
    public let projectId: UUID
    public enum CodingKeys: String, CodingKey {
      case addedBy = "added_by"
      case createdAt = "created_at"
      case profileId = "profile_id"
      case projectId = "project_id"
    }
  }
  public struct ProjectMembersInsert: Codable, Hashable, Sendable {
    public let addedBy: UUID?
    public let createdAt: String?
    public let profileId: UUID
    public let projectId: UUID
    public enum CodingKeys: String, CodingKey {
      case addedBy = "added_by"
      case createdAt = "created_at"
      case profileId = "profile_id"
      case projectId = "project_id"
    }
  }
  public struct ProjectMembersUpdate: Codable, Hashable, Sendable {
    public let addedBy: UUID?
    public let createdAt: String?
    public let profileId: UUID?
    public let projectId: UUID?
    public enum CodingKeys: String, CodingKey {
      case addedBy = "added_by"
      case createdAt = "created_at"
      case profileId = "profile_id"
      case projectId = "project_id"
    }
  }
  public struct ProjectsSelect: Codable, Hashable, Sendable {
    public let address: String?
    public let companyId: UUID
    public let coverPhotoPath: String?
    public let createdAt: String
    public let createdBy: UUID?
    public let customerDisplayName: String?
    public let description: String?
    public let id: UUID
    public let name: String
    public let status: ProjectStatus
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case address = "address"
      case companyId = "company_id"
      case coverPhotoPath = "cover_photo_path"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case customerDisplayName = "customer_display_name"
      case description = "description"
      case id = "id"
      case name = "name"
      case status = "status"
      case updatedAt = "updated_at"
    }
  }
  public struct ProjectsInsert: Codable, Hashable, Sendable {
    public let address: String?
    public let companyId: UUID
    public let coverPhotoPath: String?
    public let createdAt: String?
    public let createdBy: UUID?
    public let customerDisplayName: String?
    public let description: String?
    public let id: UUID?
    public let name: String
    public let status: ProjectStatus?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case address = "address"
      case companyId = "company_id"
      case coverPhotoPath = "cover_photo_path"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case customerDisplayName = "customer_display_name"
      case description = "description"
      case id = "id"
      case name = "name"
      case status = "status"
      case updatedAt = "updated_at"
    }
  }
  public struct ProjectsUpdate: Codable, Hashable, Sendable {
    public let address: String?
    public let companyId: UUID?
    public let coverPhotoPath: String?
    public let createdAt: String?
    public let createdBy: UUID?
    public let customerDisplayName: String?
    public let description: String?
    public let id: UUID?
    public let name: String?
    public let status: ProjectStatus?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case address = "address"
      case companyId = "company_id"
      case coverPhotoPath = "cover_photo_path"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case customerDisplayName = "customer_display_name"
      case description = "description"
      case id = "id"
      case name = "name"
      case status = "status"
      case updatedAt = "updated_at"
    }
  }
  public struct TaskAssignmentsSelect: Codable, Hashable, Sendable {
    public let assignedBy: UUID?
    public let createdAt: String
    public let profileId: UUID
    public let taskId: UUID
    public enum CodingKeys: String, CodingKey {
      case assignedBy = "assigned_by"
      case createdAt = "created_at"
      case profileId = "profile_id"
      case taskId = "task_id"
    }
  }
  public struct TaskAssignmentsInsert: Codable, Hashable, Sendable {
    public let assignedBy: UUID?
    public let createdAt: String?
    public let profileId: UUID
    public let taskId: UUID
    public enum CodingKeys: String, CodingKey {
      case assignedBy = "assigned_by"
      case createdAt = "created_at"
      case profileId = "profile_id"
      case taskId = "task_id"
    }
  }
  public struct TaskAssignmentsUpdate: Codable, Hashable, Sendable {
    public let assignedBy: UUID?
    public let createdAt: String?
    public let profileId: UUID?
    public let taskId: UUID?
    public enum CodingKeys: String, CodingKey {
      case assignedBy = "assigned_by"
      case createdAt = "created_at"
      case profileId = "profile_id"
      case taskId = "task_id"
    }
  }
  public struct TasksSelect: Codable, Hashable, Sendable {
    public let approvedAt: String?
    public let approvedBy: UUID?
    public let companyId: UUID
    public let completedAt: String?
    public let completedBy: UUID?
    public let createdAt: String
    public let createdBy: UUID?
    public let description: String?
    public let dueDate: String?
    public let id: UUID
    public let projectId: UUID
    public let sortOrder: Double
    public let status: TaskStatus
    public let title: String
    public let updatedAt: String
    public let visibleToCustomer: Bool
    public enum CodingKeys: String, CodingKey {
      case approvedAt = "approved_at"
      case approvedBy = "approved_by"
      case companyId = "company_id"
      case completedAt = "completed_at"
      case completedBy = "completed_by"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case description = "description"
      case dueDate = "due_date"
      case id = "id"
      case projectId = "project_id"
      case sortOrder = "sort_order"
      case status = "status"
      case title = "title"
      case updatedAt = "updated_at"
      case visibleToCustomer = "visible_to_customer"
    }
  }
  public struct TasksInsert: Codable, Hashable, Sendable {
    public let approvedAt: String?
    public let approvedBy: UUID?
    public let companyId: UUID
    public let completedAt: String?
    public let completedBy: UUID?
    public let createdAt: String?
    public let createdBy: UUID?
    public let description: String?
    public let dueDate: String?
    public let id: UUID?
    public let projectId: UUID
    public let sortOrder: Double?
    public let status: TaskStatus?
    public let title: String
    public let updatedAt: String?
    public let visibleToCustomer: Bool?
    public enum CodingKeys: String, CodingKey {
      case approvedAt = "approved_at"
      case approvedBy = "approved_by"
      case companyId = "company_id"
      case completedAt = "completed_at"
      case completedBy = "completed_by"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case description = "description"
      case dueDate = "due_date"
      case id = "id"
      case projectId = "project_id"
      case sortOrder = "sort_order"
      case status = "status"
      case title = "title"
      case updatedAt = "updated_at"
      case visibleToCustomer = "visible_to_customer"
    }
  }
  public struct TasksUpdate: Codable, Hashable, Sendable {
    public let approvedAt: String?
    public let approvedBy: UUID?
    public let companyId: UUID?
    public let completedAt: String?
    public let completedBy: UUID?
    public let createdAt: String?
    public let createdBy: UUID?
    public let description: String?
    public let dueDate: String?
    public let id: UUID?
    public let projectId: UUID?
    public let sortOrder: Double?
    public let status: TaskStatus?
    public let title: String?
    public let updatedAt: String?
    public let visibleToCustomer: Bool?
    public enum CodingKeys: String, CodingKey {
      case approvedAt = "approved_at"
      case approvedBy = "approved_by"
      case companyId = "company_id"
      case completedAt = "completed_at"
      case completedBy = "completed_by"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case description = "description"
      case dueDate = "due_date"
      case id = "id"
      case projectId = "project_id"
      case sortOrder = "sort_order"
      case status = "status"
      case title = "title"
      case updatedAt = "updated_at"
      case visibleToCustomer = "visible_to_customer"
    }
  }
  public struct ThreadReadStateSelect: Codable, Hashable, Sendable {
    public let lastReadAt: String
    public let lastReadMessageId: UUID?
    public let muted: Bool
    public let profileId: UUID
    public let threadId: UUID
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case lastReadAt = "last_read_at"
      case lastReadMessageId = "last_read_message_id"
      case muted = "muted"
      case profileId = "profile_id"
      case threadId = "thread_id"
      case updatedAt = "updated_at"
    }
  }
  public struct ThreadReadStateInsert: Codable, Hashable, Sendable {
    public let lastReadAt: String?
    public let lastReadMessageId: UUID?
    public let muted: Bool?
    public let profileId: UUID
    public let threadId: UUID
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case lastReadAt = "last_read_at"
      case lastReadMessageId = "last_read_message_id"
      case muted = "muted"
      case profileId = "profile_id"
      case threadId = "thread_id"
      case updatedAt = "updated_at"
    }
  }
  public struct ThreadReadStateUpdate: Codable, Hashable, Sendable {
    public let lastReadAt: String?
    public let lastReadMessageId: UUID?
    public let muted: Bool?
    public let profileId: UUID?
    public let threadId: UUID?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case lastReadAt = "last_read_at"
      case lastReadMessageId = "last_read_message_id"
      case muted = "muted"
      case profileId = "profile_id"
      case threadId = "thread_id"
      case updatedAt = "updated_at"
    }
  }
  public struct ThreadStateSelect: Codable, Hashable, Sendable {
    public let companyId: UUID
    public let createdAt: String
    public let lastExpiresAt: String?
    public let lastKind: MessageKind?
    public let lastMessageAt: String?
    public let lastMessageId: UUID?
    public let lastPreview: String?
    public let lastSenderId: UUID?
    public let messageCount: Int32
    public let projectId: UUID
    public let taskId: UUID?
    public let threadId: UUID
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case lastExpiresAt = "last_expires_at"
      case lastKind = "last_kind"
      case lastMessageAt = "last_message_at"
      case lastMessageId = "last_message_id"
      case lastPreview = "last_preview"
      case lastSenderId = "last_sender_id"
      case messageCount = "message_count"
      case projectId = "project_id"
      case taskId = "task_id"
      case threadId = "thread_id"
    }
  }
  public struct ThreadStateInsert: Codable, Hashable, Sendable {
    public let companyId: UUID
    public let createdAt: String?
    public let lastExpiresAt: String?
    public let lastKind: MessageKind?
    public let lastMessageAt: String?
    public let lastMessageId: UUID?
    public let lastPreview: String?
    public let lastSenderId: UUID?
    public let messageCount: Int32?
    public let projectId: UUID
    public let taskId: UUID?
    public let threadId: UUID
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case lastExpiresAt = "last_expires_at"
      case lastKind = "last_kind"
      case lastMessageAt = "last_message_at"
      case lastMessageId = "last_message_id"
      case lastPreview = "last_preview"
      case lastSenderId = "last_sender_id"
      case messageCount = "message_count"
      case projectId = "project_id"
      case taskId = "task_id"
      case threadId = "thread_id"
    }
  }
  public struct ThreadStateUpdate: Codable, Hashable, Sendable {
    public let companyId: UUID?
    public let createdAt: String?
    public let lastExpiresAt: String?
    public let lastKind: MessageKind?
    public let lastMessageAt: String?
    public let lastMessageId: UUID?
    public let lastPreview: String?
    public let lastSenderId: UUID?
    public let messageCount: Int32?
    public let projectId: UUID?
    public let taskId: UUID?
    public let threadId: UUID?
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case lastExpiresAt = "last_expires_at"
      case lastKind = "last_kind"
      case lastMessageAt = "last_message_at"
      case lastMessageId = "last_message_id"
      case lastPreview = "last_preview"
      case lastSenderId = "last_sender_id"
      case messageCount = "message_count"
      case projectId = "project_id"
      case taskId = "task_id"
      case threadId = "thread_id"
    }
  }
  public struct InboxThreadsSelect: Codable, Hashable, Sendable {
    public let hasUnread: Bool?
    public let lastKind: MessageKind?
    public let lastMessageAt: String?
    public let lastMessageId: UUID?
    public let lastPreview: String?
    public let lastReadAt: String?
    public let lastSenderId: UUID?
    public let messageCount: Int32?
    public let muted: Bool?
    public let projectId: UUID?
    public let projectName: String?
    public let projectStatus: ProjectStatus?
    public let taskId: UUID?
    public let taskStatus: TaskStatus?
    public let taskTitle: String?
    public let threadId: UUID?
    public enum CodingKeys: String, CodingKey {
      case hasUnread = "has_unread"
      case lastKind = "last_kind"
      case lastMessageAt = "last_message_at"
      case lastMessageId = "last_message_id"
      case lastPreview = "last_preview"
      case lastReadAt = "last_read_at"
      case lastSenderId = "last_sender_id"
      case messageCount = "message_count"
      case muted = "muted"
      case projectId = "project_id"
      case projectName = "project_name"
      case projectStatus = "project_status"
      case taskId = "task_id"
      case taskStatus = "task_status"
      case taskTitle = "task_title"
      case threadId = "thread_id"
    }
  }
  public struct PersonActivitySelect: Codable, Hashable, Sendable {
    public let lastMessageAt: String?
    public let messageCount: Int32?
    public let profileId: UUID?
    public let projectId: UUID?
    public enum CodingKeys: String, CodingKey {
      case lastMessageAt = "last_message_at"
      case messageCount = "message_count"
      case profileId = "profile_id"
      case projectId = "project_id"
    }
  }
  public struct ProjectOverviewSelect: Codable, Hashable, Sendable {
    public let address: String?
    public let approvedCount: Int32?
    public let blockedCount: Int32?
    public let companyId: UUID?
    public let coverPhotoPath: String?
    public let createdAt: String?
    public let customerDisplayName: String?
    public let doneCount: Int32?
    public let id: UUID?
    public let inProgressCount: Int32?
    public let lastActivityAt: String?
    public let latestPhotoPath: String?
    public let memberCount: Int32?
    public let name: String?
    public let status: ProjectStatus?
    public let taskCount: Int32?
    public let todoCount: Int32?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case address = "address"
      case approvedCount = "approved_count"
      case blockedCount = "blocked_count"
      case companyId = "company_id"
      case coverPhotoPath = "cover_photo_path"
      case createdAt = "created_at"
      case customerDisplayName = "customer_display_name"
      case doneCount = "done_count"
      case id = "id"
      case inProgressCount = "in_progress_count"
      case lastActivityAt = "last_activity_at"
      case latestPhotoPath = "latest_photo_path"
      case memberCount = "member_count"
      case name = "name"
      case status = "status"
      case taskCount = "task_count"
      case todoCount = "todo_count"
      case updatedAt = "updated_at"
    }
  }
}