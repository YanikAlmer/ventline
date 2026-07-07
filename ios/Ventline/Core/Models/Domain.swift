import Foundation
import SwiftUI

// Display metadata for the generated enum types, plus timestamp parsing.
// Timestamps arrive as ISO-8601 strings (the generated models keep them as
// String); parse once, format relative.

enum Timestamps {
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ value: String?) -> Date? {
        guard var value else { return nil }
        // Postgres emits "2026-07-07 12:34:56.789+00" over some paths.
        if value.contains(" ") {
            value = value.replacingOccurrences(of: " ", with: "T")
        }
        if !value.hasSuffix("Z"), !value.contains("+"), !value.dropFirst(10).contains("-") {
            value += "Z"
        }
        return isoFractional.date(from: value) ?? iso.date(from: value)
    }

    static func relative(_ value: String?) -> String {
        guard let date = parse(value) else { return "" }
        if Date().timeIntervalSince(date) < 60 { return "now" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    static func time(_ value: String?) -> String {
        guard let date = parse(value) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

extension ProjectStatus {
    var label: String {
        switch self {
        case .planning: "Planning"
        case .active: "Active"
        case .onHold: "On hold"
        case .completed: "Completed"
        case .archived: "Archived"
        }
    }

    var color: Color {
        switch self {
        case .planning: .secondary.opacity(0.8)
        case .active: .green
        case .onHold: .orange
        case .completed: .blue
        case .archived: .gray
        }
    }
}

extension TaskStatus {
    var label: String {
        switch self {
        case .todo: "To do"
        case .inProgress: "In progress"
        case .blocked: "Blocked"
        case .done: "Done"
        case .approved: "Approved"
        }
    }

    var color: Color {
        switch self {
        case .todo: .gray
        case .inProgress: .blue
        case .blocked: .red
        case .done: .orange
        case .approved: .green
        }
    }

    var systemImage: String {
        switch self {
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .blocked: "exclamationmark.octagon"
        case .done: "checkmark.circle"
        case .approved: "checkmark.seal.fill"
        }
    }
}

extension AppRole {
    var label: String {
        switch self {
        case .owner: "Owner"
        case .manager: "Manager"
        case .foreman: "Site manager"
        case .worker: "Worker"
        case .customer: "Customer"
        }
    }

    /// Owner/manager: company-wide access, people management.
    var isOffice: Bool { self == .owner || self == .manager }
    /// Roles allowed to approve tasks and edit task fields.
    var canManageTasks: Bool { isOffice || self == .foreman }
}

extension Profile {
    var initials: String {
        let parts = fullName.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }
}
