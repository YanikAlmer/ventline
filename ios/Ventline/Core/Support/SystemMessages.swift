import Foundation

/// System events ("marked the task as done") are stored in the database in
/// English so a row means the same thing to every reader regardless of who
/// triggered it. Translate at display time instead — used by both the chat
/// bubble and the conversation overview preview, so the two cannot drift.
///
/// An unrecognised body, written by an older or newer client, falls back to the
/// stored text rather than disappearing.
func localizedSystemBody(_ body: String) -> String {
    switch body {
    case "started work": String(localized: "started work")
    case "marked the task as done": String(localized: "marked the task as done")
    case "flagged the task as blocked": String(localized: "flagged the task as blocked")
    case "approved the task": String(localized: "approved the task")
    case "reopened the task": String(localized: "reopened the task")
    default: body
    }
}
