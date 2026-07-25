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

    /// The localization the app actually resolved to, which is not always the
    /// device locale: a device set to a language we do not ship falls back to
    /// German (CFBundleDevelopmentRegion). Formatting dates with this keeps
    /// timestamps in the same language as the surrounding UI.
    private static let resolvedLocale: Locale = {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "de")
    }()

    static func relative(_ value: String?) -> String {
        guard let date = parse(value) else { return "" }
        if Date().timeIntervalSince(date) < 60 { return String(localized: "now") }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = resolvedLocale
        return f.localizedString(for: date, relativeTo: Date())
    }

    static func time(_ value: String?) -> String {
        guard let date = parse(value) else { return "" }
        return date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened).locale(resolvedLocale)
        )
    }
}

extension ProjectStatus {
    var label: String {
        switch self {
        case .planning: String(localized: "Planning")
        case .active: String(localized: "Active")
        case .onHold: String(localized: "On hold")
        case .completed: String(localized: "Completed")
        case .archived: String(localized: "Archived")
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
        case .todo: String(localized: "To do")
        case .inProgress: String(localized: "In progress")
        case .blocked: String(localized: "Blocked")
        // Distinct key: the bare "Done" literal is the toolbar dismiss button
        // ("Fertig"), which is a different word from the task status ("Erledigt").
        case .done: String(localized: "task.status.done", defaultValue: "Done")
        case .approved: String(localized: "Approved")
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
        case .owner: String(localized: "Owner")
        case .manager: String(localized: "Manager")
        case .foreman: String(localized: "Site manager")
        case .worker: String(localized: "Worker")
        case .customer: String(localized: "Customer")
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

extension JobTask: @retroactive Identifiable {}
extension Attachment: @retroactive Identifiable {}

extension JobTask {
    /// Arbeitspaket (no parent) vs Arbeitsschritt (has one).
    var isWorkPackage: Bool { parentId == nil }

    /// "3. Sep" or "3. Sep, 08:00". The time is stored separately from the
    /// date and is optional, so it is appended rather than folded in.
    var dueMomentLabel: String? {
        guard let dueDate else { return nil }
        let day = Self.dueDayFormatter.string(from: dueDate)
        // Postgres renders `time` as "08:00:00"; the seconds are noise here.
        guard let dueTime, dueTime.count >= 5 else { return day }
        return "\(day), \(dueTime.prefix(5))"
    }

    private static let dueDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "de")
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f
    }()
}

private extension DateFormatter {
    func string(from dateOnly: String) -> String {
        // due_date arrives as "2026-09-03"; parse it as a plain calendar day.
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateOnly) else { return dateOnly }
        return string(from: date)
    }
}

/// A work package with its steps attached — the shape the board renders.
struct WorkPackage: Identifiable {
    let task: JobTask
    let steps: [JobTask]

    var id: UUID { task.id }

    var doneStepCount: Int {
        steps.filter { $0.status == .done || $0.status == .approved }.count
    }

    /// "4/7 Schritte", or nil when the package has no steps yet.
    var progressLabel: String? {
        guard !steps.isEmpty else { return nil }
        return String(
            format: String(localized: "%lld/%lld steps"),
            doneStepCount, steps.count
        )
    }

    /// Splits a flat task list into the two-level tree.
    ///
    /// A step whose package is absent is promoted to the top level rather than
    /// dropped. The visibility rule makes that unreachable — a step is only
    /// readable when its package is — but a task silently vanishing from a
    /// board is a far worse failure than one shown at the wrong indent.
    static func build(from tasks: [JobTask]) -> [WorkPackage] {
        let ids = Set(tasks.map(\.id))
        let roots = tasks.filter { $0.parentId == nil || !ids.contains($0.parentId!) }
        var stepsByParent: [UUID: [JobTask]] = [:]
        for task in tasks {
            guard let parentId = task.parentId, ids.contains(parentId) else { continue }
            stepsByParent[parentId, default: []].append(task)
        }
        return roots.map { WorkPackage(task: $0, steps: stepsByParent[$0.id] ?? []) }
    }
}
