import Foundation

/// Turns database errors into something a person on a jobsite can act on.
///
/// The database is the single enforcement point, which means its constraints
/// are also the last line of validation — and a constraint that fires reaches
/// the user as `new row for relation "time_entries" violates check constraint
/// "time_entries_break_fits"`. That is correct, and useless.
///
/// Only constraints a user can actually hit are listed. Anything unmapped falls
/// through to the original message rather than being swallowed: an unexpected
/// error should look unexpected, not be disguised as a friendly one.
enum FriendlyError {
    static func message(_ error: Error) -> String {
        let raw = error.localizedDescription

        for (needle, friendly) in mapping {
            if raw.contains(needle) { return friendly }
        }
        return raw
    }

    private static let mapping: [(String, String)] = [
        ("time_entries_break_fits",
         String(localized: "The break is longer than the time worked.")),
        ("time_entries_ends_after_start",
         String(localized: "The end time must be after the start time.")),
        ("time_entries_sane_span",
         String(localized: "That is more than 16 hours — check the times.")),
        ("time_entries_one_open_per_profile",
         String(localized: "A clock is already running. Stop it before starting another.")),
        ("time_entries_void_has_reason",
         String(localized: "A reason is required to delete recorded time.")),
        ("workers can only change task status",
         String(localized: "Only a site manager or the office can change that.")),
        ("workers can only update tasks assigned to them",
         String(localized: "You can only update tasks assigned to you.")),
        ("ist unterschrieben und kann nicht geaendert werden",
         String(localized: "This Rapport is signed and can no longer be changed.")),
        ("ein leerer Rapport kann nicht unterschrieben werden",
         String(localized: "Add hours or material before signing.")),
        ("der Name der unterzeichnenden Person fehlt",
         String(localized: "Please enter the name of the person signing.")),
        ("Rapport nicht gefunden oder noch nicht unterschrieben",
         String(localized: "Only a signed Rapport can be shared.")),
        ("die Zahlungsangaben des Betriebs fehlen",
         String(localized: "Add your company's IBAN in Settings before invoicing.")),
        ("customers_address_all_or_nothing",
         String(localized: "Enter the full address, or leave it empty.")),
        ("row-level security",
         String(localized: "You do not have permission to do that.")),
    ]
}
