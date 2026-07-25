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
  public enum BillingMode: String, Codable, Hashable, Sendable {
    case regie = "regie"
    case pauschal = "pauschal"
  }
  public enum DevicePlatform: String, Codable, Hashable, Sendable {
    case ios = "ios"
    case web = "web"
  }
  public enum DocumentLinkKind: String, Codable, Hashable, Sendable {
    case report = "report"
    case invoice = "invoice"
  }
  public enum DocumentType: String, Codable, Hashable, Sendable {
    case rapport = "rapport"
    case invoice = "invoice"
  }
  public enum InvoiceStatus: String, Codable, Hashable, Sendable {
    case draft = "draft"
    case issued = "issued"
    case sent = "sent"
    case paid = "paid"
    case cancelled = "cancelled"
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
  public enum MwstStatus: String, Codable, Hashable, Sendable {
    case registeredEffective = "registered_effective"
    case registeredSaldo = "registered_saldo"
    case notRegistered = "not_registered"
  }
  public enum NotificationKind: String, Codable, Hashable, Sendable {
    case chatMessage = "chat_message"
    case mention = "mention"
    case taskAssigned = "task_assigned"
    case taskStatus = "task_status"
    case taskDueSoon = "task_due_soon"
    case taskOverdue = "task_overdue"
  }
  public enum NotificationStatus: String, Codable, Hashable, Sendable {
    case pending = "pending"
    case sending = "sending"
    case sent = "sent"
    case failed = "failed"
    case skipped = "skipped"
    case expired = "expired"
  }
  public enum ProjectStatus: String, Codable, Hashable, Sendable {
    case planning = "planning"
    case active = "active"
    case onHold = "on_hold"
    case completed = "completed"
    case archived = "archived"
  }
  public enum QrReferenceType: String, Codable, Hashable, Sendable {
    case qrr = "QRR"
    case scor = "SCOR"
    case non = "NON"
  }
  public enum ReportStatus: String, Codable, Hashable, Sendable {
    case draft = "draft"
    case signed = "signed"
    case sent = "sent"
    case cancelled = "cancelled"
  }
  public enum TaskStatus: String, Codable, Hashable, Sendable {
    case todo = "todo"
    case inProgress = "in_progress"
    case blocked = "blocked"
    case done = "done"
    case approved = "approved"
  }
  public enum TimeEntryKind: String, Codable, Hashable, Sendable {
    case work = "work"
    case travel = "travel"
    case standby = "standby"
  }
  public struct AttachmentsSelect: Codable, Hashable, Sendable {
    public let byteSize: Int64?
    public let caption: String?
    public let createdAt: String
    public let durationSeconds: Double?
    public let height: Int32?
    public let id: UUID
    public let kind: AttachmentKind
    public let messageId: UUID?
    public let mimeType: String
    public let reportId: UUID?
    public let storageBucket: String
    public let storagePath: String
    public let taskId: UUID?
    public let uploadedBy: UUID?
    public let waveform: AnyJSON?
    public let width: Int32?
    public enum CodingKeys: String, CodingKey {
      case byteSize = "byte_size"
      case caption = "caption"
      case createdAt = "created_at"
      case durationSeconds = "duration_seconds"
      case height = "height"
      case id = "id"
      case kind = "kind"
      case messageId = "message_id"
      case mimeType = "mime_type"
      case reportId = "report_id"
      case storageBucket = "storage_bucket"
      case storagePath = "storage_path"
      case taskId = "task_id"
      case uploadedBy = "uploaded_by"
      case waveform = "waveform"
      case width = "width"
    }
  }
  public struct AttachmentsInsert: Codable, Hashable, Sendable {
    public let byteSize: Int64?
    public let caption: String?
    public let createdAt: String?
    public let durationSeconds: Double?
    public let height: Int32?
    public let id: UUID?
    public let kind: AttachmentKind
    public let messageId: UUID?
    public let mimeType: String
    public let reportId: UUID?
    public let storageBucket: String
    public let storagePath: String
    public let taskId: UUID?
    public let uploadedBy: UUID?
    public let waveform: AnyJSON?
    public let width: Int32?
    public enum CodingKeys: String, CodingKey {
      case byteSize = "byte_size"
      case caption = "caption"
      case createdAt = "created_at"
      case durationSeconds = "duration_seconds"
      case height = "height"
      case id = "id"
      case kind = "kind"
      case messageId = "message_id"
      case mimeType = "mime_type"
      case reportId = "report_id"
      case storageBucket = "storage_bucket"
      case storagePath = "storage_path"
      case taskId = "task_id"
      case uploadedBy = "uploaded_by"
      case waveform = "waveform"
      case width = "width"
    }
  }
  public struct AttachmentsUpdate: Codable, Hashable, Sendable {
    public let byteSize: Int64?
    public let caption: String?
    public let createdAt: String?
    public let durationSeconds: Double?
    public let height: Int32?
    public let id: UUID?
    public let kind: AttachmentKind?
    public let messageId: UUID?
    public let mimeType: String?
    public let reportId: UUID?
    public let storageBucket: String?
    public let storagePath: String?
    public let taskId: UUID?
    public let uploadedBy: UUID?
    public let waveform: AnyJSON?
    public let width: Int32?
    public enum CodingKeys: String, CodingKey {
      case byteSize = "byte_size"
      case caption = "caption"
      case createdAt = "created_at"
      case durationSeconds = "duration_seconds"
      case height = "height"
      case id = "id"
      case kind = "kind"
      case messageId = "message_id"
      case mimeType = "mime_type"
      case reportId = "report_id"
      case storageBucket = "storage_bucket"
      case storagePath = "storage_path"
      case taskId = "task_id"
      case uploadedBy = "uploaded_by"
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
  public struct CompanyBillingSettingsSelect: Codable, Hashable, Sendable {
    public let companyId: UUID
    public let createdAt: String
    public let creditorBuildingNo: String?
    public let creditorCountry: String
    public let creditorName: String
    public let creditorPostCode: String
    public let creditorStreet: String?
    public let creditorTown: String
    public let defaultHourlyRateRappen: Int64
    public let defaultMwstRateBp: Int32
    public let iban: String?
    public let logoPath: String?
    public let mwstStatus: MwstStatus
    public let paymentTermsDays: Int32
    public let saldoRateBp: Int32?
    public let showPricesOnRapport: Bool
    public let uidDigits: String?
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case creditorBuildingNo = "creditor_building_no"
      case creditorCountry = "creditor_country"
      case creditorName = "creditor_name"
      case creditorPostCode = "creditor_post_code"
      case creditorStreet = "creditor_street"
      case creditorTown = "creditor_town"
      case defaultHourlyRateRappen = "default_hourly_rate_rappen"
      case defaultMwstRateBp = "default_mwst_rate_bp"
      case iban = "iban"
      case logoPath = "logo_path"
      case mwstStatus = "mwst_status"
      case paymentTermsDays = "payment_terms_days"
      case saldoRateBp = "saldo_rate_bp"
      case showPricesOnRapport = "show_prices_on_rapport"
      case uidDigits = "uid_digits"
      case updatedAt = "updated_at"
    }
  }
  public struct CompanyBillingSettingsInsert: Codable, Hashable, Sendable {
    public let companyId: UUID
    public let createdAt: String?
    public let creditorBuildingNo: String?
    public let creditorCountry: String?
    public let creditorName: String
    public let creditorPostCode: String
    public let creditorStreet: String?
    public let creditorTown: String
    public let defaultHourlyRateRappen: Int64?
    public let defaultMwstRateBp: Int32?
    public let iban: String?
    public let logoPath: String?
    public let mwstStatus: MwstStatus?
    public let paymentTermsDays: Int32?
    public let saldoRateBp: Int32?
    public let showPricesOnRapport: Bool?
    public let uidDigits: String?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case creditorBuildingNo = "creditor_building_no"
      case creditorCountry = "creditor_country"
      case creditorName = "creditor_name"
      case creditorPostCode = "creditor_post_code"
      case creditorStreet = "creditor_street"
      case creditorTown = "creditor_town"
      case defaultHourlyRateRappen = "default_hourly_rate_rappen"
      case defaultMwstRateBp = "default_mwst_rate_bp"
      case iban = "iban"
      case logoPath = "logo_path"
      case mwstStatus = "mwst_status"
      case paymentTermsDays = "payment_terms_days"
      case saldoRateBp = "saldo_rate_bp"
      case showPricesOnRapport = "show_prices_on_rapport"
      case uidDigits = "uid_digits"
      case updatedAt = "updated_at"
    }
  }
  public struct CompanyBillingSettingsUpdate: Codable, Hashable, Sendable {
    public let companyId: UUID?
    public let createdAt: String?
    public let creditorBuildingNo: String?
    public let creditorCountry: String?
    public let creditorName: String?
    public let creditorPostCode: String?
    public let creditorStreet: String?
    public let creditorTown: String?
    public let defaultHourlyRateRappen: Int64?
    public let defaultMwstRateBp: Int32?
    public let iban: String?
    public let logoPath: String?
    public let mwstStatus: MwstStatus?
    public let paymentTermsDays: Int32?
    public let saldoRateBp: Int32?
    public let showPricesOnRapport: Bool?
    public let uidDigits: String?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case creditorBuildingNo = "creditor_building_no"
      case creditorCountry = "creditor_country"
      case creditorName = "creditor_name"
      case creditorPostCode = "creditor_post_code"
      case creditorStreet = "creditor_street"
      case creditorTown = "creditor_town"
      case defaultHourlyRateRappen = "default_hourly_rate_rappen"
      case defaultMwstRateBp = "default_mwst_rate_bp"
      case iban = "iban"
      case logoPath = "logo_path"
      case mwstStatus = "mwst_status"
      case paymentTermsDays = "payment_terms_days"
      case saldoRateBp = "saldo_rate_bp"
      case showPricesOnRapport = "show_prices_on_rapport"
      case uidDigits = "uid_digits"
      case updatedAt = "updated_at"
    }
  }
  public struct CustomersSelect: Codable, Hashable, Sendable {
    public let bexioContactId: Int64?
    public let buildingNo: String?
    public let companyId: UUID
    public let country: String?
    public let createdAt: String
    public let createdBy: UUID?
    public let email: String?
    public let id: UUID
    public let name: String
    public let notes: String?
    public let phone: String?
    public let postCode: String?
    public let street: String?
    public let town: String?
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case bexioContactId = "bexio_contact_id"
      case buildingNo = "building_no"
      case companyId = "company_id"
      case country = "country"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case email = "email"
      case id = "id"
      case name = "name"
      case notes = "notes"
      case phone = "phone"
      case postCode = "post_code"
      case street = "street"
      case town = "town"
      case updatedAt = "updated_at"
    }
  }
  public struct CustomersInsert: Codable, Hashable, Sendable {
    public let bexioContactId: Int64?
    public let buildingNo: String?
    public let companyId: UUID
    public let country: String?
    public let createdAt: String?
    public let createdBy: UUID?
    public let email: String?
    public let id: UUID?
    public let name: String
    public let notes: String?
    public let phone: String?
    public let postCode: String?
    public let street: String?
    public let town: String?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case bexioContactId = "bexio_contact_id"
      case buildingNo = "building_no"
      case companyId = "company_id"
      case country = "country"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case email = "email"
      case id = "id"
      case name = "name"
      case notes = "notes"
      case phone = "phone"
      case postCode = "post_code"
      case street = "street"
      case town = "town"
      case updatedAt = "updated_at"
    }
  }
  public struct CustomersUpdate: Codable, Hashable, Sendable {
    public let bexioContactId: Int64?
    public let buildingNo: String?
    public let companyId: UUID?
    public let country: String?
    public let createdAt: String?
    public let createdBy: UUID?
    public let email: String?
    public let id: UUID?
    public let name: String?
    public let notes: String?
    public let phone: String?
    public let postCode: String?
    public let street: String?
    public let town: String?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case bexioContactId = "bexio_contact_id"
      case buildingNo = "building_no"
      case companyId = "company_id"
      case country = "country"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case email = "email"
      case id = "id"
      case name = "name"
      case notes = "notes"
      case phone = "phone"
      case postCode = "post_code"
      case street = "street"
      case town = "town"
      case updatedAt = "updated_at"
    }
  }
  public struct DevicesSelect: Codable, Hashable, Sendable {
    public let apnsEnvironment: String
    public let appVersion: String?
    public let createdAt: String
    public let id: UUID
    public let installId: UUID
    public let lastSeenAt: String
    public let locale: String
    public let platform: DevicePlatform
    public let profileId: UUID
    public let pushToken: String
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case apnsEnvironment = "apns_environment"
      case appVersion = "app_version"
      case createdAt = "created_at"
      case id = "id"
      case installId = "install_id"
      case lastSeenAt = "last_seen_at"
      case locale = "locale"
      case platform = "platform"
      case profileId = "profile_id"
      case pushToken = "push_token"
      case updatedAt = "updated_at"
    }
  }
  public struct DevicesInsert: Codable, Hashable, Sendable {
    public let apnsEnvironment: String?
    public let appVersion: String?
    public let createdAt: String?
    public let id: UUID?
    public let installId: UUID
    public let lastSeenAt: String?
    public let locale: String?
    public let platform: DevicePlatform
    public let profileId: UUID
    public let pushToken: String
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case apnsEnvironment = "apns_environment"
      case appVersion = "app_version"
      case createdAt = "created_at"
      case id = "id"
      case installId = "install_id"
      case lastSeenAt = "last_seen_at"
      case locale = "locale"
      case platform = "platform"
      case profileId = "profile_id"
      case pushToken = "push_token"
      case updatedAt = "updated_at"
    }
  }
  public struct DevicesUpdate: Codable, Hashable, Sendable {
    public let apnsEnvironment: String?
    public let appVersion: String?
    public let createdAt: String?
    public let id: UUID?
    public let installId: UUID?
    public let lastSeenAt: String?
    public let locale: String?
    public let platform: DevicePlatform?
    public let profileId: UUID?
    public let pushToken: String?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case apnsEnvironment = "apns_environment"
      case appVersion = "app_version"
      case createdAt = "created_at"
      case id = "id"
      case installId = "install_id"
      case lastSeenAt = "last_seen_at"
      case locale = "locale"
      case platform = "platform"
      case profileId = "profile_id"
      case pushToken = "push_token"
      case updatedAt = "updated_at"
    }
  }
  public struct DocumentLinkViewsSelect: Codable, Hashable, Sendable {
    public let id: Int64
    public let linkId: UUID
    public let userAgentFamily: String?
    public let viewedAt: String
    public enum CodingKeys: String, CodingKey {
      case id = "id"
      case linkId = "link_id"
      case userAgentFamily = "user_agent_family"
      case viewedAt = "viewed_at"
    }
  }
  public struct DocumentLinkViewsInsert: Codable, Hashable, Sendable {
    public let id: Int64?
    public let linkId: UUID
    public let userAgentFamily: String?
    public let viewedAt: String?
    public enum CodingKeys: String, CodingKey {
      case id = "id"
      case linkId = "link_id"
      case userAgentFamily = "user_agent_family"
      case viewedAt = "viewed_at"
    }
  }
  public struct DocumentLinkViewsUpdate: Codable, Hashable, Sendable {
    public let id: Int64?
    public let linkId: UUID?
    public let userAgentFamily: String?
    public let viewedAt: String?
    public enum CodingKeys: String, CodingKey {
      case id = "id"
      case linkId = "link_id"
      case userAgentFamily = "user_agent_family"
      case viewedAt = "viewed_at"
    }
  }
  public struct DocumentLinksSelect: Codable, Hashable, Sendable {
    public let companyId: UUID
    public let createdAt: String
    public let createdBy: UUID?
    public let expiresAt: String
    public let id: UUID
    public let invoiceId: UUID?
    public let kind: DocumentLinkKind
    public let lastViewedAt: String?
    public let reportId: UUID?
    public let revokedAt: String?
    public let tokenHash: String
    public let viewCount: Int32
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case expiresAt = "expires_at"
      case id = "id"
      case invoiceId = "invoice_id"
      case kind = "kind"
      case lastViewedAt = "last_viewed_at"
      case reportId = "report_id"
      case revokedAt = "revoked_at"
      case tokenHash = "token_hash"
      case viewCount = "view_count"
    }
  }
  public struct DocumentLinksInsert: Codable, Hashable, Sendable {
    public let companyId: UUID
    public let createdAt: String?
    public let createdBy: UUID?
    public let expiresAt: String
    public let id: UUID?
    public let invoiceId: UUID?
    public let kind: DocumentLinkKind
    public let lastViewedAt: String?
    public let reportId: UUID?
    public let revokedAt: String?
    public let tokenHash: String
    public let viewCount: Int32?
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case expiresAt = "expires_at"
      case id = "id"
      case invoiceId = "invoice_id"
      case kind = "kind"
      case lastViewedAt = "last_viewed_at"
      case reportId = "report_id"
      case revokedAt = "revoked_at"
      case tokenHash = "token_hash"
      case viewCount = "view_count"
    }
  }
  public struct DocumentLinksUpdate: Codable, Hashable, Sendable {
    public let companyId: UUID?
    public let createdAt: String?
    public let createdBy: UUID?
    public let expiresAt: String?
    public let id: UUID?
    public let invoiceId: UUID?
    public let kind: DocumentLinkKind?
    public let lastViewedAt: String?
    public let reportId: UUID?
    public let revokedAt: String?
    public let tokenHash: String?
    public let viewCount: Int32?
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case expiresAt = "expires_at"
      case id = "id"
      case invoiceId = "invoice_id"
      case kind = "kind"
      case lastViewedAt = "last_viewed_at"
      case reportId = "report_id"
      case revokedAt = "revoked_at"
      case tokenHash = "token_hash"
      case viewCount = "view_count"
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
  public struct InvoiceLinesSelect: Codable, Hashable, Sendable {
    public let description: String
    public let id: UUID
    public let invoiceId: UUID
    public let mwstRateBp: Int32
    public let netRappen: Int64
    public let quantityMilli: Int64
    public let serviceDate: String?
    public let sortOrder: Int32
    public let unit: String
    public let unitPriceRappen: Int64
    public enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case invoiceId = "invoice_id"
      case mwstRateBp = "mwst_rate_bp"
      case netRappen = "net_rappen"
      case quantityMilli = "quantity_milli"
      case serviceDate = "service_date"
      case sortOrder = "sort_order"
      case unit = "unit"
      case unitPriceRappen = "unit_price_rappen"
    }
  }
  public struct InvoiceLinesInsert: Codable, Hashable, Sendable {
    public let description: String
    public let id: UUID?
    public let invoiceId: UUID
    public let mwstRateBp: Int32?
    public let netRappen: Int64?
    public let quantityMilli: Int64?
    public let serviceDate: String?
    public let sortOrder: Int32?
    public let unit: String?
    public let unitPriceRappen: Int64?
    public enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case invoiceId = "invoice_id"
      case mwstRateBp = "mwst_rate_bp"
      case netRappen = "net_rappen"
      case quantityMilli = "quantity_milli"
      case serviceDate = "service_date"
      case sortOrder = "sort_order"
      case unit = "unit"
      case unitPriceRappen = "unit_price_rappen"
    }
  }
  public struct InvoiceLinesUpdate: Codable, Hashable, Sendable {
    public let description: String?
    public let id: UUID?
    public let invoiceId: UUID?
    public let mwstRateBp: Int32?
    public let netRappen: Int64?
    public let quantityMilli: Int64?
    public let serviceDate: String?
    public let sortOrder: Int32?
    public let unit: String?
    public let unitPriceRappen: Int64?
    public enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case invoiceId = "invoice_id"
      case mwstRateBp = "mwst_rate_bp"
      case netRappen = "net_rappen"
      case quantityMilli = "quantity_milli"
      case serviceDate = "service_date"
      case sortOrder = "sort_order"
      case unit = "unit"
      case unitPriceRappen = "unit_price_rappen"
    }
  }
  public struct InvoiceTaxGroupsSelect: Codable, Hashable, Sendable {
    public let invoiceId: UUID
    public let netRappen: Int64
    public let rateBp: Int32
    public let taxRappen: Int64
    public enum CodingKeys: String, CodingKey {
      case invoiceId = "invoice_id"
      case netRappen = "net_rappen"
      case rateBp = "rate_bp"
      case taxRappen = "tax_rappen"
    }
  }
  public struct InvoiceTaxGroupsInsert: Codable, Hashable, Sendable {
    public let invoiceId: UUID
    public let netRappen: Int64
    public let rateBp: Int32
    public let taxRappen: Int64
    public enum CodingKeys: String, CodingKey {
      case invoiceId = "invoice_id"
      case netRappen = "net_rappen"
      case rateBp = "rate_bp"
      case taxRappen = "tax_rappen"
    }
  }
  public struct InvoiceTaxGroupsUpdate: Codable, Hashable, Sendable {
    public let invoiceId: UUID?
    public let netRappen: Int64?
    public let rateBp: Int32?
    public let taxRappen: Int64?
    public enum CodingKeys: String, CodingKey {
      case invoiceId = "invoice_id"
      case netRappen = "net_rappen"
      case rateBp = "rate_bp"
      case taxRappen = "tax_rappen"
    }
  }
  public struct InvoicesSelect: Codable, Hashable, Sendable {
    public let bexioInvoiceId: Int64?
    public let bexioSyncError: String?
    public let bexioSyncedAt: String?
    public let companyId: UUID
    public let createdAt: String
    public let createdBy: UUID?
    public let creditorBuildingNo: String?
    public let creditorCountry: String?
    public let creditorIban: String?
    public let creditorMwstStatus: MwstStatus?
    public let creditorName: String?
    public let creditorPostCode: String?
    public let creditorStreet: String?
    public let creditorTown: String?
    public let creditorUidDigits: String?
    public let currency: String
    public let customerId: UUID
    public let debtorBuildingNo: String?
    public let debtorCountry: String?
    public let debtorName: String?
    public let debtorPostCode: String?
    public let debtorStreet: String?
    public let debtorTown: String?
    public let dueDate: String?
    public let id: UUID
    public let invoiceDate: String?
    public let number: Int64?
    public let numberText: String?
    public let paidAt: String?
    public let pdfGeneratedAt: String?
    public let pdfPath: String?
    public let pdfSha256: String?
    public let periodKey: String?
    public let projectId: UUID
    public let qrPayload: String?
    public let qrSpecVersion: String
    public let reference: String?
    public let referenceType: QrReferenceType?
    public let reportId: UUID?
    public let sentAt: String?
    public let serviceDateFrom: String?
    public let serviceDateTo: String?
    public let status: InvoiceStatus
    public let totalGrossRappen: Int64
    public let totalNetRappen: Int64
    public let totalTaxRappen: Int64
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case bexioInvoiceId = "bexio_invoice_id"
      case bexioSyncError = "bexio_sync_error"
      case bexioSyncedAt = "bexio_synced_at"
      case companyId = "company_id"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case creditorBuildingNo = "creditor_building_no"
      case creditorCountry = "creditor_country"
      case creditorIban = "creditor_iban"
      case creditorMwstStatus = "creditor_mwst_status"
      case creditorName = "creditor_name"
      case creditorPostCode = "creditor_post_code"
      case creditorStreet = "creditor_street"
      case creditorTown = "creditor_town"
      case creditorUidDigits = "creditor_uid_digits"
      case currency = "currency"
      case customerId = "customer_id"
      case debtorBuildingNo = "debtor_building_no"
      case debtorCountry = "debtor_country"
      case debtorName = "debtor_name"
      case debtorPostCode = "debtor_post_code"
      case debtorStreet = "debtor_street"
      case debtorTown = "debtor_town"
      case dueDate = "due_date"
      case id = "id"
      case invoiceDate = "invoice_date"
      case number = "number"
      case numberText = "number_text"
      case paidAt = "paid_at"
      case pdfGeneratedAt = "pdf_generated_at"
      case pdfPath = "pdf_path"
      case pdfSha256 = "pdf_sha256"
      case periodKey = "period_key"
      case projectId = "project_id"
      case qrPayload = "qr_payload"
      case qrSpecVersion = "qr_spec_version"
      case reference = "reference"
      case referenceType = "reference_type"
      case reportId = "report_id"
      case sentAt = "sent_at"
      case serviceDateFrom = "service_date_from"
      case serviceDateTo = "service_date_to"
      case status = "status"
      case totalGrossRappen = "total_gross_rappen"
      case totalNetRappen = "total_net_rappen"
      case totalTaxRappen = "total_tax_rappen"
      case updatedAt = "updated_at"
    }
  }
  public struct InvoicesInsert: Codable, Hashable, Sendable {
    public let bexioInvoiceId: Int64?
    public let bexioSyncError: String?
    public let bexioSyncedAt: String?
    public let companyId: UUID
    public let createdAt: String?
    public let createdBy: UUID?
    public let creditorBuildingNo: String?
    public let creditorCountry: String?
    public let creditorIban: String?
    public let creditorMwstStatus: MwstStatus?
    public let creditorName: String?
    public let creditorPostCode: String?
    public let creditorStreet: String?
    public let creditorTown: String?
    public let creditorUidDigits: String?
    public let currency: String?
    public let customerId: UUID
    public let debtorBuildingNo: String?
    public let debtorCountry: String?
    public let debtorName: String?
    public let debtorPostCode: String?
    public let debtorStreet: String?
    public let debtorTown: String?
    public let dueDate: String?
    public let id: UUID?
    public let invoiceDate: String?
    public let number: Int64?
    public let numberText: String?
    public let paidAt: String?
    public let pdfGeneratedAt: String?
    public let pdfPath: String?
    public let pdfSha256: String?
    public let periodKey: String?
    public let projectId: UUID
    public let qrPayload: String?
    public let qrSpecVersion: String?
    public let reference: String?
    public let referenceType: QrReferenceType?
    public let reportId: UUID?
    public let sentAt: String?
    public let serviceDateFrom: String?
    public let serviceDateTo: String?
    public let status: InvoiceStatus?
    public let totalGrossRappen: Int64?
    public let totalNetRappen: Int64?
    public let totalTaxRappen: Int64?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case bexioInvoiceId = "bexio_invoice_id"
      case bexioSyncError = "bexio_sync_error"
      case bexioSyncedAt = "bexio_synced_at"
      case companyId = "company_id"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case creditorBuildingNo = "creditor_building_no"
      case creditorCountry = "creditor_country"
      case creditorIban = "creditor_iban"
      case creditorMwstStatus = "creditor_mwst_status"
      case creditorName = "creditor_name"
      case creditorPostCode = "creditor_post_code"
      case creditorStreet = "creditor_street"
      case creditorTown = "creditor_town"
      case creditorUidDigits = "creditor_uid_digits"
      case currency = "currency"
      case customerId = "customer_id"
      case debtorBuildingNo = "debtor_building_no"
      case debtorCountry = "debtor_country"
      case debtorName = "debtor_name"
      case debtorPostCode = "debtor_post_code"
      case debtorStreet = "debtor_street"
      case debtorTown = "debtor_town"
      case dueDate = "due_date"
      case id = "id"
      case invoiceDate = "invoice_date"
      case number = "number"
      case numberText = "number_text"
      case paidAt = "paid_at"
      case pdfGeneratedAt = "pdf_generated_at"
      case pdfPath = "pdf_path"
      case pdfSha256 = "pdf_sha256"
      case periodKey = "period_key"
      case projectId = "project_id"
      case qrPayload = "qr_payload"
      case qrSpecVersion = "qr_spec_version"
      case reference = "reference"
      case referenceType = "reference_type"
      case reportId = "report_id"
      case sentAt = "sent_at"
      case serviceDateFrom = "service_date_from"
      case serviceDateTo = "service_date_to"
      case status = "status"
      case totalGrossRappen = "total_gross_rappen"
      case totalNetRappen = "total_net_rappen"
      case totalTaxRappen = "total_tax_rappen"
      case updatedAt = "updated_at"
    }
  }
  public struct InvoicesUpdate: Codable, Hashable, Sendable {
    public let bexioInvoiceId: Int64?
    public let bexioSyncError: String?
    public let bexioSyncedAt: String?
    public let companyId: UUID?
    public let createdAt: String?
    public let createdBy: UUID?
    public let creditorBuildingNo: String?
    public let creditorCountry: String?
    public let creditorIban: String?
    public let creditorMwstStatus: MwstStatus?
    public let creditorName: String?
    public let creditorPostCode: String?
    public let creditorStreet: String?
    public let creditorTown: String?
    public let creditorUidDigits: String?
    public let currency: String?
    public let customerId: UUID?
    public let debtorBuildingNo: String?
    public let debtorCountry: String?
    public let debtorName: String?
    public let debtorPostCode: String?
    public let debtorStreet: String?
    public let debtorTown: String?
    public let dueDate: String?
    public let id: UUID?
    public let invoiceDate: String?
    public let number: Int64?
    public let numberText: String?
    public let paidAt: String?
    public let pdfGeneratedAt: String?
    public let pdfPath: String?
    public let pdfSha256: String?
    public let periodKey: String?
    public let projectId: UUID?
    public let qrPayload: String?
    public let qrSpecVersion: String?
    public let reference: String?
    public let referenceType: QrReferenceType?
    public let reportId: UUID?
    public let sentAt: String?
    public let serviceDateFrom: String?
    public let serviceDateTo: String?
    public let status: InvoiceStatus?
    public let totalGrossRappen: Int64?
    public let totalNetRappen: Int64?
    public let totalTaxRappen: Int64?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case bexioInvoiceId = "bexio_invoice_id"
      case bexioSyncError = "bexio_sync_error"
      case bexioSyncedAt = "bexio_synced_at"
      case companyId = "company_id"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case creditorBuildingNo = "creditor_building_no"
      case creditorCountry = "creditor_country"
      case creditorIban = "creditor_iban"
      case creditorMwstStatus = "creditor_mwst_status"
      case creditorName = "creditor_name"
      case creditorPostCode = "creditor_post_code"
      case creditorStreet = "creditor_street"
      case creditorTown = "creditor_town"
      case creditorUidDigits = "creditor_uid_digits"
      case currency = "currency"
      case customerId = "customer_id"
      case debtorBuildingNo = "debtor_building_no"
      case debtorCountry = "debtor_country"
      case debtorName = "debtor_name"
      case debtorPostCode = "debtor_post_code"
      case debtorStreet = "debtor_street"
      case debtorTown = "debtor_town"
      case dueDate = "due_date"
      case id = "id"
      case invoiceDate = "invoice_date"
      case number = "number"
      case numberText = "number_text"
      case paidAt = "paid_at"
      case pdfGeneratedAt = "pdf_generated_at"
      case pdfPath = "pdf_path"
      case pdfSha256 = "pdf_sha256"
      case periodKey = "period_key"
      case projectId = "project_id"
      case qrPayload = "qr_payload"
      case qrSpecVersion = "qr_spec_version"
      case reference = "reference"
      case referenceType = "reference_type"
      case reportId = "report_id"
      case sentAt = "sent_at"
      case serviceDateFrom = "service_date_from"
      case serviceDateTo = "service_date_to"
      case status = "status"
      case totalGrossRappen = "total_gross_rappen"
      case totalNetRappen = "total_net_rappen"
      case totalTaxRappen = "total_tax_rappen"
      case updatedAt = "updated_at"
    }
  }
  public struct MaterialLinesSelect: Codable, Hashable, Sendable {
    public let companyId: UUID
    public let createdAt: String
    public let description: String
    public let id: UUID
    public let projectId: UUID
    public let quantityMilli: Int64
    public let recordedBy: UUID?
    public let taskId: UUID?
    public let unit: String
    public let unitPriceRappen: Int64
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case description = "description"
      case id = "id"
      case projectId = "project_id"
      case quantityMilli = "quantity_milli"
      case recordedBy = "recorded_by"
      case taskId = "task_id"
      case unit = "unit"
      case unitPriceRappen = "unit_price_rappen"
      case updatedAt = "updated_at"
    }
  }
  public struct MaterialLinesInsert: Codable, Hashable, Sendable {
    public let companyId: UUID
    public let createdAt: String?
    public let description: String
    public let id: UUID?
    public let projectId: UUID
    public let quantityMilli: Int64
    public let recordedBy: UUID?
    public let taskId: UUID?
    public let unit: String?
    public let unitPriceRappen: Int64?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case description = "description"
      case id = "id"
      case projectId = "project_id"
      case quantityMilli = "quantity_milli"
      case recordedBy = "recorded_by"
      case taskId = "task_id"
      case unit = "unit"
      case unitPriceRappen = "unit_price_rappen"
      case updatedAt = "updated_at"
    }
  }
  public struct MaterialLinesUpdate: Codable, Hashable, Sendable {
    public let companyId: UUID?
    public let createdAt: String?
    public let description: String?
    public let id: UUID?
    public let projectId: UUID?
    public let quantityMilli: Int64?
    public let recordedBy: UUID?
    public let taskId: UUID?
    public let unit: String?
    public let unitPriceRappen: Int64?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case createdAt = "created_at"
      case description = "description"
      case id = "id"
      case projectId = "project_id"
      case quantityMilli = "quantity_milli"
      case recordedBy = "recorded_by"
      case taskId = "task_id"
      case unit = "unit"
      case unitPriceRappen = "unit_price_rappen"
      case updatedAt = "updated_at"
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
    public let searchTsv: String?
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
    public let searchTsv: String?
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
    public let searchTsv: String?
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
  public struct NotificationDeliveriesSelect: Codable, Hashable, Sendable {
    public let deliveredAt: String
    public let deviceId: UUID
    public let outboxId: UUID
    public enum CodingKeys: String, CodingKey {
      case deliveredAt = "delivered_at"
      case deviceId = "device_id"
      case outboxId = "outbox_id"
    }
  }
  public struct NotificationDeliveriesInsert: Codable, Hashable, Sendable {
    public let deliveredAt: String?
    public let deviceId: UUID
    public let outboxId: UUID
    public enum CodingKeys: String, CodingKey {
      case deliveredAt = "delivered_at"
      case deviceId = "device_id"
      case outboxId = "outbox_id"
    }
  }
  public struct NotificationDeliveriesUpdate: Codable, Hashable, Sendable {
    public let deliveredAt: String?
    public let deviceId: UUID?
    public let outboxId: UUID?
    public enum CodingKeys: String, CodingKey {
      case deliveredAt = "delivered_at"
      case deviceId = "device_id"
      case outboxId = "outbox_id"
    }
  }
  public struct NotificationOutboxSelect: Codable, Hashable, Sendable {
    public let actorId: UUID?
    public let attempts: Int32
    public let companyId: UUID
    public let createdAt: String
    public let dedupeKey: String
    public let id: UUID
    public let kind: NotificationKind
    public let lastError: String?
    public let messageId: UUID?
    public let nextAttemptAt: String
    public let payload: AnyJSON
    public let processedAt: String?
    public let projectId: UUID
    public let status: NotificationStatus
    public let targetId: UUID?
    public let taskId: UUID?
    public enum CodingKeys: String, CodingKey {
      case actorId = "actor_id"
      case attempts = "attempts"
      case companyId = "company_id"
      case createdAt = "created_at"
      case dedupeKey = "dedupe_key"
      case id = "id"
      case kind = "kind"
      case lastError = "last_error"
      case messageId = "message_id"
      case nextAttemptAt = "next_attempt_at"
      case payload = "payload"
      case processedAt = "processed_at"
      case projectId = "project_id"
      case status = "status"
      case targetId = "target_id"
      case taskId = "task_id"
    }
  }
  public struct NotificationOutboxInsert: Codable, Hashable, Sendable {
    public let actorId: UUID?
    public let attempts: Int32?
    public let companyId: UUID
    public let createdAt: String?
    public let dedupeKey: String
    public let id: UUID?
    public let kind: NotificationKind
    public let lastError: String?
    public let messageId: UUID?
    public let nextAttemptAt: String?
    public let payload: AnyJSON?
    public let processedAt: String?
    public let projectId: UUID
    public let status: NotificationStatus?
    public let targetId: UUID?
    public let taskId: UUID?
    public enum CodingKeys: String, CodingKey {
      case actorId = "actor_id"
      case attempts = "attempts"
      case companyId = "company_id"
      case createdAt = "created_at"
      case dedupeKey = "dedupe_key"
      case id = "id"
      case kind = "kind"
      case lastError = "last_error"
      case messageId = "message_id"
      case nextAttemptAt = "next_attempt_at"
      case payload = "payload"
      case processedAt = "processed_at"
      case projectId = "project_id"
      case status = "status"
      case targetId = "target_id"
      case taskId = "task_id"
    }
  }
  public struct NotificationOutboxUpdate: Codable, Hashable, Sendable {
    public let actorId: UUID?
    public let attempts: Int32?
    public let companyId: UUID?
    public let createdAt: String?
    public let dedupeKey: String?
    public let id: UUID?
    public let kind: NotificationKind?
    public let lastError: String?
    public let messageId: UUID?
    public let nextAttemptAt: String?
    public let payload: AnyJSON?
    public let processedAt: String?
    public let projectId: UUID?
    public let status: NotificationStatus?
    public let targetId: UUID?
    public let taskId: UUID?
    public enum CodingKeys: String, CodingKey {
      case actorId = "actor_id"
      case attempts = "attempts"
      case companyId = "company_id"
      case createdAt = "created_at"
      case dedupeKey = "dedupe_key"
      case id = "id"
      case kind = "kind"
      case lastError = "last_error"
      case messageId = "message_id"
      case nextAttemptAt = "next_attempt_at"
      case payload = "payload"
      case processedAt = "processed_at"
      case projectId = "project_id"
      case status = "status"
      case targetId = "target_id"
      case taskId = "task_id"
    }
  }
  public struct NotificationPrefsSelect: Codable, Hashable, Sendable {
    public let chatEnabled: Bool
    public let createdAt: String
    public let deadlinesEnabled: Bool
    public let mentionsEnabled: Bool
    public let profileId: UUID
    public let pushEnabled: Bool
    public let quietHoursEnabled: Bool
    public let quietHoursEnd: String
    public let quietHoursStart: String
    public let taskAssignedEnabled: Bool
    public let taskStatusEnabled: Bool
    public let timeZone: String
    public let updatedAt: String
    public let watchAllProjects: Bool
    public enum CodingKeys: String, CodingKey {
      case chatEnabled = "chat_enabled"
      case createdAt = "created_at"
      case deadlinesEnabled = "deadlines_enabled"
      case mentionsEnabled = "mentions_enabled"
      case profileId = "profile_id"
      case pushEnabled = "push_enabled"
      case quietHoursEnabled = "quiet_hours_enabled"
      case quietHoursEnd = "quiet_hours_end"
      case quietHoursStart = "quiet_hours_start"
      case taskAssignedEnabled = "task_assigned_enabled"
      case taskStatusEnabled = "task_status_enabled"
      case timeZone = "time_zone"
      case updatedAt = "updated_at"
      case watchAllProjects = "watch_all_projects"
    }
  }
  public struct NotificationPrefsInsert: Codable, Hashable, Sendable {
    public let chatEnabled: Bool?
    public let createdAt: String?
    public let deadlinesEnabled: Bool?
    public let mentionsEnabled: Bool?
    public let profileId: UUID
    public let pushEnabled: Bool?
    public let quietHoursEnabled: Bool?
    public let quietHoursEnd: String?
    public let quietHoursStart: String?
    public let taskAssignedEnabled: Bool?
    public let taskStatusEnabled: Bool?
    public let timeZone: String?
    public let updatedAt: String?
    public let watchAllProjects: Bool?
    public enum CodingKeys: String, CodingKey {
      case chatEnabled = "chat_enabled"
      case createdAt = "created_at"
      case deadlinesEnabled = "deadlines_enabled"
      case mentionsEnabled = "mentions_enabled"
      case profileId = "profile_id"
      case pushEnabled = "push_enabled"
      case quietHoursEnabled = "quiet_hours_enabled"
      case quietHoursEnd = "quiet_hours_end"
      case quietHoursStart = "quiet_hours_start"
      case taskAssignedEnabled = "task_assigned_enabled"
      case taskStatusEnabled = "task_status_enabled"
      case timeZone = "time_zone"
      case updatedAt = "updated_at"
      case watchAllProjects = "watch_all_projects"
    }
  }
  public struct NotificationPrefsUpdate: Codable, Hashable, Sendable {
    public let chatEnabled: Bool?
    public let createdAt: String?
    public let deadlinesEnabled: Bool?
    public let mentionsEnabled: Bool?
    public let profileId: UUID?
    public let pushEnabled: Bool?
    public let quietHoursEnabled: Bool?
    public let quietHoursEnd: String?
    public let quietHoursStart: String?
    public let taskAssignedEnabled: Bool?
    public let taskStatusEnabled: Bool?
    public let timeZone: String?
    public let updatedAt: String?
    public let watchAllProjects: Bool?
    public enum CodingKeys: String, CodingKey {
      case chatEnabled = "chat_enabled"
      case createdAt = "created_at"
      case deadlinesEnabled = "deadlines_enabled"
      case mentionsEnabled = "mentions_enabled"
      case profileId = "profile_id"
      case pushEnabled = "push_enabled"
      case quietHoursEnabled = "quiet_hours_enabled"
      case quietHoursEnd = "quiet_hours_end"
      case quietHoursStart = "quiet_hours_start"
      case taskAssignedEnabled = "task_assigned_enabled"
      case taskStatusEnabled = "task_status_enabled"
      case timeZone = "time_zone"
      case updatedAt = "updated_at"
      case watchAllProjects = "watch_all_projects"
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
  public struct ProjectNotificationMutesSelect: Codable, Hashable, Sendable {
    public let createdAt: String
    public let mutedUntil: String?
    public let profileId: UUID
    public let projectId: UUID
    public enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case mutedUntil = "muted_until"
      case profileId = "profile_id"
      case projectId = "project_id"
    }
  }
  public struct ProjectNotificationMutesInsert: Codable, Hashable, Sendable {
    public let createdAt: String?
    public let mutedUntil: String?
    public let profileId: UUID
    public let projectId: UUID
    public enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case mutedUntil = "muted_until"
      case profileId = "profile_id"
      case projectId = "project_id"
    }
  }
  public struct ProjectNotificationMutesUpdate: Codable, Hashable, Sendable {
    public let createdAt: String?
    public let mutedUntil: String?
    public let profileId: UUID?
    public let projectId: UUID?
    public enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case mutedUntil = "muted_until"
      case profileId = "profile_id"
      case projectId = "project_id"
    }
  }
  public struct ProjectsSelect: Codable, Hashable, Sendable {
    public let address: String?
    public let billingMode: BillingMode
    public let companyId: UUID
    public let coverPhotoPath: String?
    public let createdAt: String
    public let createdBy: UUID?
    public let customerDisplayName: String?
    public let customerId: UUID?
    public let description: String?
    public let id: UUID
    public let name: String
    public let status: ProjectStatus
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case address = "address"
      case billingMode = "billing_mode"
      case companyId = "company_id"
      case coverPhotoPath = "cover_photo_path"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case customerDisplayName = "customer_display_name"
      case customerId = "customer_id"
      case description = "description"
      case id = "id"
      case name = "name"
      case status = "status"
      case updatedAt = "updated_at"
    }
  }
  public struct ProjectsInsert: Codable, Hashable, Sendable {
    public let address: String?
    public let billingMode: BillingMode?
    public let companyId: UUID
    public let coverPhotoPath: String?
    public let createdAt: String?
    public let createdBy: UUID?
    public let customerDisplayName: String?
    public let customerId: UUID?
    public let description: String?
    public let id: UUID?
    public let name: String
    public let status: ProjectStatus?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case address = "address"
      case billingMode = "billing_mode"
      case companyId = "company_id"
      case coverPhotoPath = "cover_photo_path"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case customerDisplayName = "customer_display_name"
      case customerId = "customer_id"
      case description = "description"
      case id = "id"
      case name = "name"
      case status = "status"
      case updatedAt = "updated_at"
    }
  }
  public struct ProjectsUpdate: Codable, Hashable, Sendable {
    public let address: String?
    public let billingMode: BillingMode?
    public let companyId: UUID?
    public let coverPhotoPath: String?
    public let createdAt: String?
    public let createdBy: UUID?
    public let customerDisplayName: String?
    public let customerId: UUID?
    public let description: String?
    public let id: UUID?
    public let name: String?
    public let status: ProjectStatus?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case address = "address"
      case billingMode = "billing_mode"
      case companyId = "company_id"
      case coverPhotoPath = "cover_photo_path"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case customerDisplayName = "customer_display_name"
      case customerId = "customer_id"
      case description = "description"
      case id = "id"
      case name = "name"
      case status = "status"
      case updatedAt = "updated_at"
    }
  }
  public struct ReportMaterialLinesSelect: Codable, Hashable, Sendable {
    public let description: String
    public let id: UUID
    public let materialLineId: UUID?
    public let quantityMilli: Int64
    public let reportId: UUID
    public let sortOrder: Int32
    public let unit: String
    public let unitPriceRappen: Int64
    public enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case materialLineId = "material_line_id"
      case quantityMilli = "quantity_milli"
      case reportId = "report_id"
      case sortOrder = "sort_order"
      case unit = "unit"
      case unitPriceRappen = "unit_price_rappen"
    }
  }
  public struct ReportMaterialLinesInsert: Codable, Hashable, Sendable {
    public let description: String
    public let id: UUID?
    public let materialLineId: UUID?
    public let quantityMilli: Int64
    public let reportId: UUID
    public let sortOrder: Int32?
    public let unit: String?
    public let unitPriceRappen: Int64?
    public enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case materialLineId = "material_line_id"
      case quantityMilli = "quantity_milli"
      case reportId = "report_id"
      case sortOrder = "sort_order"
      case unit = "unit"
      case unitPriceRappen = "unit_price_rappen"
    }
  }
  public struct ReportMaterialLinesUpdate: Codable, Hashable, Sendable {
    public let description: String?
    public let id: UUID?
    public let materialLineId: UUID?
    public let quantityMilli: Int64?
    public let reportId: UUID?
    public let sortOrder: Int32?
    public let unit: String?
    public let unitPriceRappen: Int64?
    public enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case materialLineId = "material_line_id"
      case quantityMilli = "quantity_milli"
      case reportId = "report_id"
      case sortOrder = "sort_order"
      case unit = "unit"
      case unitPriceRappen = "unit_price_rappen"
    }
  }
  public struct ReportPhotosSelect: Codable, Hashable, Sendable {
    public let attachmentId: UUID
    public let reportId: UUID
    public let sortOrder: Int32
    public enum CodingKeys: String, CodingKey {
      case attachmentId = "attachment_id"
      case reportId = "report_id"
      case sortOrder = "sort_order"
    }
  }
  public struct ReportPhotosInsert: Codable, Hashable, Sendable {
    public let attachmentId: UUID
    public let reportId: UUID
    public let sortOrder: Int32?
    public enum CodingKeys: String, CodingKey {
      case attachmentId = "attachment_id"
      case reportId = "report_id"
      case sortOrder = "sort_order"
    }
  }
  public struct ReportPhotosUpdate: Codable, Hashable, Sendable {
    public let attachmentId: UUID?
    public let reportId: UUID?
    public let sortOrder: Int32?
    public enum CodingKeys: String, CodingKey {
      case attachmentId = "attachment_id"
      case reportId = "report_id"
      case sortOrder = "sort_order"
    }
  }
  public struct ReportTimeLinesSelect: Codable, Hashable, Sendable {
    public let description: String?
    public let id: UUID
    public let minutes: Int32
    public let performedByName: String?
    public let performedOn: String
    public let profileId: UUID?
    public let rateRappen: Int64
    public let reportId: UUID
    public let sortOrder: Int32
    public let sourceRevision: Int32?
    public let timeEntryId: UUID?
    public enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case minutes = "minutes"
      case performedByName = "performed_by_name"
      case performedOn = "performed_on"
      case profileId = "profile_id"
      case rateRappen = "rate_rappen"
      case reportId = "report_id"
      case sortOrder = "sort_order"
      case sourceRevision = "source_revision"
      case timeEntryId = "time_entry_id"
    }
  }
  public struct ReportTimeLinesInsert: Codable, Hashable, Sendable {
    public let description: String?
    public let id: UUID?
    public let minutes: Int32
    public let performedByName: String?
    public let performedOn: String
    public let profileId: UUID?
    public let rateRappen: Int64?
    public let reportId: UUID
    public let sortOrder: Int32?
    public let sourceRevision: Int32?
    public let timeEntryId: UUID?
    public enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case minutes = "minutes"
      case performedByName = "performed_by_name"
      case performedOn = "performed_on"
      case profileId = "profile_id"
      case rateRappen = "rate_rappen"
      case reportId = "report_id"
      case sortOrder = "sort_order"
      case sourceRevision = "source_revision"
      case timeEntryId = "time_entry_id"
    }
  }
  public struct ReportTimeLinesUpdate: Codable, Hashable, Sendable {
    public let description: String?
    public let id: UUID?
    public let minutes: Int32?
    public let performedByName: String?
    public let performedOn: String?
    public let profileId: UUID?
    public let rateRappen: Int64?
    public let reportId: UUID?
    public let sortOrder: Int32?
    public let sourceRevision: Int32?
    public let timeEntryId: UUID?
    public enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case minutes = "minutes"
      case performedByName = "performed_by_name"
      case performedOn = "performed_on"
      case profileId = "profile_id"
      case rateRappen = "rate_rappen"
      case reportId = "report_id"
      case sortOrder = "sort_order"
      case sourceRevision = "source_revision"
      case timeEntryId = "time_entry_id"
    }
  }
  public struct ReportsSelect: Codable, Hashable, Sendable {
    public let companyId: UUID
    public let contentHash: String?
    public let correctsReportId: UUID?
    public let createdAt: String
    public let createdBy: UUID?
    public let customerId: UUID?
    public let docType: DocumentType
    public let id: UUID
    public let number: Int64?
    public let numberText: String?
    public let pdfGeneratedAt: String?
    public let pdfPath: String?
    public let pdfSha256: String?
    public let periodFrom: String?
    public let periodKey: String?
    public let periodTo: String?
    public let projectId: UUID
    public let sentAt: String?
    public let signaturePath: String?
    public let signedAt: String?
    public let signerName: String?
    public let snapshot: AnyJSON?
    public let status: ReportStatus
    public let summary: String?
    public let title: String?
    public let totalNetRappen: Int64?
    public let updatedAt: String
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case contentHash = "content_hash"
      case correctsReportId = "corrects_report_id"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case customerId = "customer_id"
      case docType = "doc_type"
      case id = "id"
      case number = "number"
      case numberText = "number_text"
      case pdfGeneratedAt = "pdf_generated_at"
      case pdfPath = "pdf_path"
      case pdfSha256 = "pdf_sha256"
      case periodFrom = "period_from"
      case periodKey = "period_key"
      case periodTo = "period_to"
      case projectId = "project_id"
      case sentAt = "sent_at"
      case signaturePath = "signature_path"
      case signedAt = "signed_at"
      case signerName = "signer_name"
      case snapshot = "snapshot"
      case status = "status"
      case summary = "summary"
      case title = "title"
      case totalNetRappen = "total_net_rappen"
      case updatedAt = "updated_at"
    }
  }
  public struct ReportsInsert: Codable, Hashable, Sendable {
    public let companyId: UUID
    public let contentHash: String?
    public let correctsReportId: UUID?
    public let createdAt: String?
    public let createdBy: UUID?
    public let customerId: UUID?
    public let docType: DocumentType?
    public let id: UUID?
    public let number: Int64?
    public let numberText: String?
    public let pdfGeneratedAt: String?
    public let pdfPath: String?
    public let pdfSha256: String?
    public let periodFrom: String?
    public let periodKey: String?
    public let periodTo: String?
    public let projectId: UUID
    public let sentAt: String?
    public let signaturePath: String?
    public let signedAt: String?
    public let signerName: String?
    public let snapshot: AnyJSON?
    public let status: ReportStatus?
    public let summary: String?
    public let title: String?
    public let totalNetRappen: Int64?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case contentHash = "content_hash"
      case correctsReportId = "corrects_report_id"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case customerId = "customer_id"
      case docType = "doc_type"
      case id = "id"
      case number = "number"
      case numberText = "number_text"
      case pdfGeneratedAt = "pdf_generated_at"
      case pdfPath = "pdf_path"
      case pdfSha256 = "pdf_sha256"
      case periodFrom = "period_from"
      case periodKey = "period_key"
      case periodTo = "period_to"
      case projectId = "project_id"
      case sentAt = "sent_at"
      case signaturePath = "signature_path"
      case signedAt = "signed_at"
      case signerName = "signer_name"
      case snapshot = "snapshot"
      case status = "status"
      case summary = "summary"
      case title = "title"
      case totalNetRappen = "total_net_rappen"
      case updatedAt = "updated_at"
    }
  }
  public struct ReportsUpdate: Codable, Hashable, Sendable {
    public let companyId: UUID?
    public let contentHash: String?
    public let correctsReportId: UUID?
    public let createdAt: String?
    public let createdBy: UUID?
    public let customerId: UUID?
    public let docType: DocumentType?
    public let id: UUID?
    public let number: Int64?
    public let numberText: String?
    public let pdfGeneratedAt: String?
    public let pdfPath: String?
    public let pdfSha256: String?
    public let periodFrom: String?
    public let periodKey: String?
    public let periodTo: String?
    public let projectId: UUID?
    public let sentAt: String?
    public let signaturePath: String?
    public let signedAt: String?
    public let signerName: String?
    public let snapshot: AnyJSON?
    public let status: ReportStatus?
    public let summary: String?
    public let title: String?
    public let totalNetRappen: Int64?
    public let updatedAt: String?
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case contentHash = "content_hash"
      case correctsReportId = "corrects_report_id"
      case createdAt = "created_at"
      case createdBy = "created_by"
      case customerId = "customer_id"
      case docType = "doc_type"
      case id = "id"
      case number = "number"
      case numberText = "number_text"
      case pdfGeneratedAt = "pdf_generated_at"
      case pdfPath = "pdf_path"
      case pdfSha256 = "pdf_sha256"
      case periodFrom = "period_from"
      case periodKey = "period_key"
      case periodTo = "period_to"
      case projectId = "project_id"
      case sentAt = "sent_at"
      case signaturePath = "signature_path"
      case signedAt = "signed_at"
      case signerName = "signer_name"
      case snapshot = "snapshot"
      case status = "status"
      case summary = "summary"
      case title = "title"
      case totalNetRappen = "total_net_rappen"
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
    public let dueTime: String?
    public let id: UUID
    public let parentId: UUID?
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
      case dueTime = "due_time"
      case id = "id"
      case parentId = "parent_id"
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
    public let dueTime: String?
    public let id: UUID?
    public let parentId: UUID?
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
      case dueTime = "due_time"
      case id = "id"
      case parentId = "parent_id"
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
    public let dueTime: String?
    public let id: UUID?
    public let parentId: UUID?
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
      case dueTime = "due_time"
      case id = "id"
      case parentId = "parent_id"
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
  public struct TimeEntriesSelect: Codable, Hashable, Sendable {
    public let breakMinutes: Int32
    public let companyId: UUID
    public let createdAt: String
    public let endedAt: String?
    public let id: UUID
    public let kind: TimeEntryKind
    public let note: String?
    public let profileId: UUID
    public let projectId: UUID
    public let recordedBy: UUID?
    public let revision: Int32
    public let startedAt: String
    public let taskId: UUID?
    public let updatedAt: String
    public let voidedAt: String?
    public let voidedReason: String?
    public let workDate: String
    public let workedMinutes: Int32?
    public enum CodingKeys: String, CodingKey {
      case breakMinutes = "break_minutes"
      case companyId = "company_id"
      case createdAt = "created_at"
      case endedAt = "ended_at"
      case id = "id"
      case kind = "kind"
      case note = "note"
      case profileId = "profile_id"
      case projectId = "project_id"
      case recordedBy = "recorded_by"
      case revision = "revision"
      case startedAt = "started_at"
      case taskId = "task_id"
      case updatedAt = "updated_at"
      case voidedAt = "voided_at"
      case voidedReason = "voided_reason"
      case workDate = "work_date"
      case workedMinutes = "worked_minutes"
    }
  }
  public struct TimeEntriesInsert: Codable, Hashable, Sendable {
    public let breakMinutes: Int32?
    public let companyId: UUID
    public let createdAt: String?
    public let endedAt: String?
    public let id: UUID?
    public let kind: TimeEntryKind?
    public let note: String?
    public let profileId: UUID
    public let projectId: UUID
    public let recordedBy: UUID?
    public let revision: Int32?
    public let startedAt: String
    public let taskId: UUID?
    public let updatedAt: String?
    public let voidedAt: String?
    public let voidedReason: String?
    public let workDate: String
    public let workedMinutes: Int32?
    public enum CodingKeys: String, CodingKey {
      case breakMinutes = "break_minutes"
      case companyId = "company_id"
      case createdAt = "created_at"
      case endedAt = "ended_at"
      case id = "id"
      case kind = "kind"
      case note = "note"
      case profileId = "profile_id"
      case projectId = "project_id"
      case recordedBy = "recorded_by"
      case revision = "revision"
      case startedAt = "started_at"
      case taskId = "task_id"
      case updatedAt = "updated_at"
      case voidedAt = "voided_at"
      case voidedReason = "voided_reason"
      case workDate = "work_date"
      case workedMinutes = "worked_minutes"
    }
  }
  public struct TimeEntriesUpdate: Codable, Hashable, Sendable {
    public let breakMinutes: Int32?
    public let companyId: UUID?
    public let createdAt: String?
    public let endedAt: String?
    public let id: UUID?
    public let kind: TimeEntryKind?
    public let note: String?
    public let profileId: UUID?
    public let projectId: UUID?
    public let recordedBy: UUID?
    public let revision: Int32?
    public let startedAt: String?
    public let taskId: UUID?
    public let updatedAt: String?
    public let voidedAt: String?
    public let voidedReason: String?
    public let workDate: String?
    public let workedMinutes: Int32?
    public enum CodingKeys: String, CodingKey {
      case breakMinutes = "break_minutes"
      case companyId = "company_id"
      case createdAt = "created_at"
      case endedAt = "ended_at"
      case id = "id"
      case kind = "kind"
      case note = "note"
      case profileId = "profile_id"
      case projectId = "project_id"
      case recordedBy = "recorded_by"
      case revision = "revision"
      case startedAt = "started_at"
      case taskId = "task_id"
      case updatedAt = "updated_at"
      case voidedAt = "voided_at"
      case voidedReason = "voided_reason"
      case workDate = "work_date"
      case workedMinutes = "worked_minutes"
    }
  }
  public struct TimeEntryRevisionsSelect: Codable, Hashable, Sendable {
    public let after: AnyJSON?
    public let before: AnyJSON?
    public let changedAt: String
    public let changedBy: UUID?
    public let companyId: UUID
    public let id: Int64
    public let op: String
    public let reason: String?
    public let revision: Int32
    public let timeEntryId: UUID
    public enum CodingKeys: String, CodingKey {
      case after = "after"
      case before = "before"
      case changedAt = "changed_at"
      case changedBy = "changed_by"
      case companyId = "company_id"
      case id = "id"
      case op = "op"
      case reason = "reason"
      case revision = "revision"
      case timeEntryId = "time_entry_id"
    }
  }
  public struct TimeEntryRevisionsInsert: Codable, Hashable, Sendable {
    public let after: AnyJSON?
    public let before: AnyJSON?
    public let changedAt: String?
    public let changedBy: UUID?
    public let companyId: UUID
    public let id: Int64?
    public let op: String
    public let reason: String?
    public let revision: Int32
    public let timeEntryId: UUID
    public enum CodingKeys: String, CodingKey {
      case after = "after"
      case before = "before"
      case changedAt = "changed_at"
      case changedBy = "changed_by"
      case companyId = "company_id"
      case id = "id"
      case op = "op"
      case reason = "reason"
      case revision = "revision"
      case timeEntryId = "time_entry_id"
    }
  }
  public struct TimeEntryRevisionsUpdate: Codable, Hashable, Sendable {
    public let after: AnyJSON?
    public let before: AnyJSON?
    public let changedAt: String?
    public let changedBy: UUID?
    public let companyId: UUID?
    public let id: Int64?
    public let op: String?
    public let reason: String?
    public let revision: Int32?
    public let timeEntryId: UUID?
    public enum CodingKeys: String, CodingKey {
      case after = "after"
      case before = "before"
      case changedAt = "changed_at"
      case changedBy = "changed_by"
      case companyId = "company_id"
      case id = "id"
      case op = "op"
      case reason = "reason"
      case revision = "revision"
      case timeEntryId = "time_entry_id"
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
  public struct NumberSeriesAuditSelect: Codable, Hashable, Sendable {
    public let companyId: UUID?
    public let docType: DocumentType?
    public let highest: Int64?
    public let issued: Int32?
    public let lowest: Int64?
    public let missing: Int32?
    public let periodKey: String?
    public enum CodingKeys: String, CodingKey {
      case companyId = "company_id"
      case docType = "doc_type"
      case highest = "highest"
      case issued = "issued"
      case lowest = "lowest"
      case missing = "missing"
      case periodKey = "period_key"
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
  public struct ReportDivergencesSelect: Codable, Hashable, Sendable {
    public let deltaMinutes: Int32?
    public let hasCorrection: Bool?
    public let isAlreadyACorrection: Bool?
    public let minutesNow: Int32?
    public let minutesOnPaper: Int32?
    public let numberText: String?
    public let projectId: UUID?
    public let reportId: UUID?
    public let sourceWasVoided: Bool?
    public let timeEntryId: UUID?
    public enum CodingKeys: String, CodingKey {
      case deltaMinutes = "delta_minutes"
      case hasCorrection = "has_correction"
      case isAlreadyACorrection = "is_already_a_correction"
      case minutesNow = "minutes_now"
      case minutesOnPaper = "minutes_on_paper"
      case numberText = "number_text"
      case projectId = "project_id"
      case reportId = "report_id"
      case sourceWasVoided = "source_was_voided"
      case timeEntryId = "time_entry_id"
    }
  }
}