import Foundation

/// Mentions and task references — the iOS half of the contract the web client
/// writes. See `web/src/lib/annotations.ts`; the two must agree exactly, since
/// a message composed on a phone is read in a browser and the other way round.
///
/// The body stays plain text: "@Wanda Müller" is literally in `messages.body`
/// and the range is recorded beside it, so every reader that knows nothing
/// about annotations — the push preview, the inbox preview, the customer
/// portal — still shows a name rather than a token or a gap.
///
/// **Offsets are UTF-16 code units**, which is what `String.utf16` gives and
/// what a JavaScript string indexes in natively. That is the whole reason for
/// the `utf16` dance below rather than the far more natural `String.Index`
/// arithmetic: Swift's default view is grapheme clusters, and a family emoji
/// earlier in the message would silently shift every offset the web client
/// wrote.
enum Annotations {
    struct Pending: Equatable {
        enum Kind: String { case mention, task }
        let kind: Kind
        /// profile_id for a mention, task_id for a reference.
        let id: UUID
        /// Exactly the run inserted into the body, including the @ or #.
        let text: String
    }

    struct Resolved {
        let pending: Pending
        let start: Int
        let length: Int
    }

    /// Offsets are computed **once, from the final text**, rather than
    /// maintained through every keystroke. Someone types around a mention,
    /// deletes half of it, pastes over it; tracking a live range through all
    /// of that is where the off-by-ones live, and none of them are visible
    /// until a message renders wrong somewhere else.
    ///
    /// A run the user edited away is dropped — which is right, because a name
    /// that is no longer in the text should not notify anybody.
    static func resolve(body: String, pending: [Pending]) -> [Resolved] {
        let units = Array(body.utf16)
        var claimed: [(Int, Int)] = []
        var resolved: [Resolved] = []

        for item in pending where !item.text.isEmpty {
            let needle = Array(item.text.utf16)
            var from = 0
            var found: Int?

            while from + needle.count <= units.count {
                if let index = firstIndex(of: needle, in: units, from: from) {
                    let end = index + needle.count
                    let overlaps = claimed.contains { index < $0.1 && end > $0.0 }
                    if !overlaps {
                        found = index
                        break
                    }
                    // The same person can be mentioned twice, so each pending
                    // entry has to claim a *different* occurrence.
                    from = index + 1
                } else {
                    break
                }
            }

            guard let start = found else { continue }
            claimed.append((start, start + needle.count))
            resolved.append(Resolved(pending: item, start: start, length: needle.count))
        }

        return resolved.sorted { $0.start < $1.start }
    }

    private static func firstIndex(
        of needle: [UInt16], in haystack: [UInt16], from: Int
    ) -> Int? {
        guard !needle.isEmpty, needle.count <= haystack.count else { return nil }
        var i = max(0, from)
        while i + needle.count <= haystack.count {
            var matched = true
            var j = 0
            while j < needle.count {
                if haystack[i + j] != needle[j] {
                    matched = false
                    break
                }
                j += 1
            }
            if matched { return i }
            i += 1
        }
        return nil
    }

    // MARK: - Payloads for send_message

    static func mentionsPayload(_ resolved: [Resolved]) -> [[String: AnyEncodableJSON]] {
        resolved.filter { $0.pending.kind == .mention }.map {
            [
                "profile_id": .string($0.pending.id.uuidString.lowercased()),
                "start_offset": .int($0.start),
                "length": .int($0.length),
            ]
        }
    }

    static func refsPayload(_ resolved: [Resolved]) -> [[String: AnyEncodableJSON]] {
        resolved.filter { $0.pending.kind == .task }.map {
            [
                "kind": .string("task"),
                "task_id": .string($0.pending.id.uuidString.lowercased()),
                "start_offset": .int($0.start),
                "length": .int($0.length),
            ]
        }
    }

    // MARK: - Display

    struct Stored {
        let kind: Pending.Kind
        let id: UUID
        let start: Int?
        let length: Int?
    }

    enum Segment {
        case text(String)
        case mention(String, profileId: UUID)
        case task(String, taskId: UUID)
    }

    /// Split a body into plain and annotated runs.
    ///
    /// Every stored range is treated as a **hint that must still be true**. A
    /// row whose offsets fall outside the body, or overlap one already taken,
    /// is skipped and its text renders plain. These offsets were written by a
    /// different client, possibly years earlier: a wrong highlight is
    /// acceptable, a crash or a garbled message is not.
    static func segments(body: String, annotations: [Stored]) -> [Segment] {
        let units = Array(body.utf16)
        let usable = annotations
            .compactMap { annotation -> (Stored, Int, Int)? in
                guard let start = annotation.start, let length = annotation.length,
                      length > 0, start >= 0, start + length <= units.count
                else { return nil }
                return (annotation, start, length)
            }
            .sorted { $0.1 < $1.1 }

        var segments: [Segment] = []
        var cursor = 0

        for (annotation, start, length) in usable {
            if start < cursor { continue }
            if start > cursor, let gap = string(units[cursor..<start]) {
                segments.append(.text(gap))
            }
            if let run = string(units[start..<(start + length)]) {
                switch annotation.kind {
                case .mention: segments.append(.mention(run, profileId: annotation.id))
                case .task: segments.append(.task(run, taskId: annotation.id))
                }
            }
            cursor = start + length
        }

        if cursor < units.count, let tail = string(units[cursor..<units.count]) {
            segments.append(.text(tail))
        }
        return segments
    }

    /// Slicing UTF-16 can land between the halves of a surrogate pair when the
    /// offsets came from somewhere that counted differently. That produces an
    /// unpaired surrogate, which is not a valid String — so the run is dropped
    /// rather than force-unwrapped into a crash.
    private static func string(_ slice: ArraySlice<UInt16>) -> String? {
        String(utf16CodeUnits: Array(slice), count: slice.count)
    }

    // MARK: - The token being typed

    struct Trigger: Equatable {
        enum Sigil: String { case mention = "@", task = "#" }
        let sigil: Sigil
        let query: String
        /// UTF-16 offset of the sigil, so the whole run can be replaced.
        let start: Int
    }

    /// The token at the caret, if any.
    ///
    /// Anchored to a word boundary so an email address does not open the
    /// picker halfway through, and capped at 40 characters so a paragraph
    /// containing a stray `@` stops querying after the first word.
    static func trigger(in text: String, caret: Int) -> Trigger? {
        let units = Array(text.utf16)
        guard caret > 0, caret <= units.count else { return nil }

        var index = caret - 1
        var queryUnits: [UInt16] = []
        while index >= 0 {
            let unit = units[index]
            if unit == 0x40 || unit == 0x23 { // @ or #
                // Must start a word: preceded by nothing, whitespace, ( or [.
                if index > 0 {
                    let before = units[index - 1]
                    let isBoundary = before == 0x20 || before == 0x0A || before == 0x09
                        || before == 0x28 || before == 0x5B
                    if !isBoundary { return nil }
                }
                let sigil: Trigger.Sigil = unit == 0x40 ? .mention : .task
                let query = String(utf16CodeUnits: queryUnits.reversed(), count: queryUnits.count)
                return Trigger(sigil: sigil, query: query, start: index)
            }
            // The run ends at whitespace, and stops looking after 40 units.
            if unit == 0x20 || unit == 0x0A || unit == 0x09 { return nil }
            if queryUnits.count >= 40 { return nil }
            queryUnits.append(unit)
            index -= 1
        }
        return nil
    }

    /// Replace the triggered run with the chosen text, plus a trailing space so
    /// the next word cannot glue itself onto the name and break the exact-run
    /// match at send time.
    ///
    /// The range comes entirely from the trigger, never from a second read of
    /// the caret: on the web the equivalent bug duplicated everything typed
    /// since the selection last moved.
    static func apply(
        trigger: Trigger, choosing text: String, in body: String
    ) -> (body: String, caret: Int) {
        let units = Array(body.utf16)
        let runEnd = min(units.count, trigger.start + 1 + trigger.query.utf16.count)
        let inserted = Array("\(text) ".utf16)
        let next = Array(units[0..<trigger.start]) + inserted + Array(units[runEnd...])
        return (
            String(utf16CodeUnits: next, count: next.count),
            trigger.start + inserted.count
        )
    }
}

/// The narrow JSON shape the send_message params need. supabase-swift's AnyJSON
/// would do, but this keeps the payload builders free of its import.
enum AnyEncodableJSON: Encodable {
    case string(String)
    case int(Int)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        }
    }
}
