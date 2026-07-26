import Foundation
import Observation
import Supabase
import UIKit

/// One chat thread (task-scoped, or project-level when taskId is nil).
/// Paged history + realtime inserts + optimistic sends.
@Observable
@MainActor
final class ChatViewModel {
    struct Item: Identifiable {
        enum State {
            case sent(Message)
            case sending(localId: UUID)
            case failed(localId: UUID, retry: () -> Void)
        }

        var id: UUID {
            switch state {
            case .sent(let message): message.id
            case .sending(let localId), .failed(let localId, _): localId
            }
        }

        var state: State
        var body: String?
        var kind: MessageKind
        var senderId: UUID
        var createdAt: String
        var sharedWithCustomer: Bool
        var attachments: [Attachment] = []
        var annotationsByAttachment: [UUID: PhotoAnnotation] = [:]
        /// Mentions and task references, as ranges into `body`.
        var textAnnotations: [Annotations.Stored] = []
        /// Local preview for optimistic photo sends.
        var localImage: UIImage?
    }

    let projectId: UUID
    let taskId: UUID?
    let profile: Profile

    private(set) var items: [Item] = []
    /// Set when the thread was opened from a search hit, so the view can scroll
    /// to that message and mark it.
    private(set) var focusMessageId: UUID?

    /// thread_state keys on `coalesce(task_id, project_id)`, so this is the
    /// same identity the inbox counts unread against.
    var threadId: UUID { taskId ?? projectId }

    /// Clears the unread badge and acknowledges any mentions in the thread.
    ///
    /// Called on open and again on leaving: opening covers what was already
    /// there, leaving covers whatever arrived while it was on screen. Until
    /// now nothing called this at all on iOS, so an unread badge — and an
    /// unacknowledged mention, which is what drives the attention list — could
    /// never clear from the phone.
    func markRead() async {
        try? await InboxRepo.markRead(threadId: threadId)
    }
    private(set) var isLoading = false
    private(set) var isLoadingOlder = false
    private(set) var canLoadOlder = false
    var errorMessage: String?

    private var channel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var senderCache: [UUID: Profile] = [:]

    init(projectId: UUID, taskId: UUID?, profile: Profile) {
        self.projectId = projectId
        self.taskId = taskId
        self.profile = profile
    }

    func senderName(_ id: UUID) -> String {
        if id == profile.id { return String(localized: "You") }
        return senderCache[id]?.fullName ?? String(localized: "Teammate")
    }

    /// The person's actual name, never "You". System rows read
    /// "<name> hat die Aufgabe freigegeben", and substituting "Du" there would
    /// produce "Du hat …" — the verb is conjugated for the third person, so the
    /// row has to name the person even when that person is you.
    func senderFullName(_ id: UUID) -> String {
        if id == profile.id { return profile.fullName }
        return senderCache[id]?.fullName ?? String(localized: "Teammate")
    }

    // MARK: - Loading

    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let messages = try await MessageRepo.page(projectId: projectId, taskId: taskId)
            canLoadOlder = messages.count >= MessageRepo.pageSize
            items = try await hydrate(messages)
            await loadSenders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Opens on a window around one message instead of the newest page.
    func loadAround(messageId: UUID) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let window = try await MessageRepo.around(messageId: messageId)
            guard !window.isEmpty else {
                // Deleted, expired, or not visible to this reader. The newest
                // page beats an empty thread.
                await loadInitial()
                return
            }
            items = try await hydrate(window)
            // There is always more above a window, and the button costs
            // nothing; the alternative is a thread that looks truncated.
            canLoadOlder = true
            focusMessageId = messageId
            await loadSenders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadOlder() async {
        // Guard against overlapping loads: a second tap before the first
        // returns would re-fetch the same page and insert duplicate items
        // (duplicate SwiftUI ids).
        guard !isLoadingOlder else { return }
        guard let oldest = items.first(where: {
            if case .sent = $0.state { return true } else { return false }
        })?.createdAt else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let older = try await MessageRepo.page(projectId: projectId, taskId: taskId, before: oldest)
            canLoadOlder = older.count >= MessageRepo.pageSize
            let hydrated = try await hydrate(older)
            // Defensive dedup in case a realtime insert already added one.
            let existingIds = Set(items.map(\.id))
            let fresh = hydrated.filter { !existingIds.contains($0.id) }
            items.insert(contentsOf: fresh, at: 0)
            await loadSenders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hydrate(_ messages: [Message]) async throws -> [Item] {
        let ids = messages.map(\.id)
        let attachments = try await MessageRepo.attachments(messageIds: ids)
        let annotations = try await MessageRepo.annotations(attachmentIds: attachments.map(\.id))
        // One request each for the whole page, not one per bubble.
        let mentions = try await MessageRepo.mentions(messageIds: ids)
        let refs = try await MessageRepo.refs(messageIds: ids)
        var newestAnnotation: [UUID: PhotoAnnotation] = [:]
        for annotation in annotations.reversed() {
            newestAnnotation[annotation.attachmentId] = annotation
        }
        return messages.map { message in
            let mine = attachments.filter { $0.messageId == message.id }
            let text = Self.storedAnnotations(
                for: message.id, mentions: mentions, refs: refs)
            return Item(
                state: .sent(message),
                body: message.body,
                kind: message.kind,
                senderId: message.senderId,
                createdAt: message.createdAt,
                sharedWithCustomer: message.sharedWithCustomer,
                attachments: mine,
                annotationsByAttachment: newestAnnotation.filter { key, _ in
                    mine.contains { $0.id == key }
                },
                textAnnotations: text
            )
        }
    }

    /// Mentions and task references for one message, as ranges into its body.
    ///
    /// Written as plain loops on purpose. The first version was one expression —
    /// a `.filter{}.map{}` array joined by `+` to a `.filter{}.compactMap{}`
    /// whose closure used `guard let … else { return nil }` — and it made the
    /// constraint solver give up: `+` is overloaded across every numeric type,
    /// `String` and `Array`, and the element type of both sides had to be
    /// inferred *through* that overload set and back out of a multi-statement
    /// closure.
    ///
    /// When the solver times out, Swift abandons the whole file and reports
    /// every unresolved name in it as "cannot find type in scope" — so a
    /// single slow expression here produced twenty errors pointing at
    /// perfectly good code elsewhere, including types from other files. It
    /// compiled on a fast machine and failed on a busy one, which is the worst
    /// property a build can have.
    ///
    /// `Int($0)` rather than `Int.init`, for the same reason: the bare
    /// initialiser is overloaded across every numeric type and adds work the
    /// solver does not need to do.
    private static func storedAnnotations(
        for messageId: UUID,
        mentions: [MessageMention],
        refs: [MessageRef]
    ) -> [Annotations.Stored] {
        var stored: [Annotations.Stored] = []

        for mention in mentions where mention.messageId == messageId {
            stored.append(Annotations.Stored(
                kind: .mention,
                id: mention.mentionedProfileId,
                start: mention.startOffset.map { Int($0) },
                length: mention.length.map { Int($0) }
            ))
        }

        for ref in refs where ref.messageId == messageId {
            guard let taskId = ref.taskId else { continue }
            stored.append(Annotations.Stored(
                kind: .task,
                id: taskId,
                start: ref.startOffset.map { Int($0) },
                length: ref.length.map { Int($0) }
            ))
        }

        return stored
    }

    private func loadSenders() async {
        let missing = Set(items.map(\.senderId)).subtracting(senderCache.keys)
        guard !missing.isEmpty else { return }
        do {
            let profiles: [Profile] = try await Supa.client
                .from("profiles")
                .select()
                .in("id", values: missing.map { $0 as any PostgrestFilterValue })
                .execute()
                .value
            for profile in profiles {
                senderCache[profile.id] = profile
            }
        } catch {
            // Names stay as placeholders; not worth surfacing.
        }
    }

    // MARK: - Realtime

    func startRealtime() {
        guard realtimeTask == nil else { return }
        let channel = Supa.client.channel("thread-\(taskId?.uuidString ?? projectId.uuidString)")
        self.channel = channel

        let filter: RealtimePostgresFilter = if let taskId {
            .eq("task_id", value: taskId)
        } else {
            .eq("project_id", value: projectId)
        }
        let inserts = channel.postgresChange(
            InsertAction.self, schema: "public", table: "messages", filter: filter
        )

        realtimeTask = Task {
            do {
                try await channel.subscribeWithError()
            } catch {
                // Realtime unavailable: paged history still works, so fail
                // quietly rather than surfacing an error for a non-critical
                // live-update path.
                return
            }
            for await insert in inserts {
                guard let message = try? insert.decodeRecord(as: Message.self, decoder: JSONDecoder()) else {
                    continue
                }
                await self.mergeIncoming(message)
            }
        }
    }

    func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel {
            let client = Supa.client
            Task { await client.removeChannel(channel) }
        }
        channel = nil
    }

    private func mergeIncoming(_ message: Message) async {
        // Project-level channel also receives task-thread inserts; filter.
        guard message.taskId == taskId else { return }
        guard !items.contains(where: { $0.id == message.id }) else { return }
        if let hydrated = try? await hydrate([message]) {
            items.append(contentsOf: hydrated)
            await loadSenders()
        }
    }

    // MARK: - Sending

    func sendText(
        _ text: String,
        sharedWithCustomer: Bool,
        pending: [Annotations.Pending] = []
    ) {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        // Resolved against the text actually being sent, so a name edited away
        // between picking and sending simply does not notify.
        let resolved = Annotations.resolve(body: body, pending: pending)
        sendOptimistic(kind: .text, body: body, image: nil, sharedWithCustomer: sharedWithCustomer) {
            try await MessageRepo.send(
                projectId: self.projectId, taskId: self.taskId,
                kind: .text, body: body, sharedWithCustomer: sharedWithCustomer,
                mentions: Annotations.mentionsPayload(resolved),
                refs: Annotations.refsPayload(resolved)
            )
        }
    }

    func sendPhoto(
        _ image: UIImage,
        caption: String?,
        sharedWithCustomer: Bool,
        pending: [Annotations.Pending] = []
    ) {
        let resolved = Annotations.resolve(body: caption ?? "", pending: pending)
        sendOptimistic(kind: .photo, body: caption, image: image, sharedWithCustomer: sharedWithCustomer) {
            let uploaded = try await MediaUploader.uploadPhoto(
                image, companyId: self.profile.companyId, projectId: self.projectId
            )
            return try await MessageRepo.send(
                projectId: self.projectId, taskId: self.taskId,
                kind: .photo, body: caption,
                attachments: [uploaded.attachmentPayload],
                sharedWithCustomer: sharedWithCustomer,
                mentions: Annotations.mentionsPayload(resolved),
                refs: Annotations.refsPayload(resolved)
            )
        }
    }

    func sendVoice(fileURL: URL, duration: Double) {
        sendOptimistic(kind: .voice, body: nil, image: nil, sharedWithCustomer: false) {
            let uploaded = try await MediaUploader.uploadVoice(
                fileURL: fileURL, duration: duration,
                companyId: self.profile.companyId, projectId: self.projectId
            )
            return try await MessageRepo.send(
                projectId: self.projectId, taskId: self.taskId,
                kind: .voice, body: nil,
                attachments: [uploaded.attachmentPayload]
            )
        }
    }

    func sendSystem(_ body: String) {
        Task {
            _ = try? await MessageRepo.send(
                projectId: projectId, taskId: taskId, kind: .system, body: body
            )
        }
    }

    func deleteMessage(_ item: Item) {
        guard case .sent(let message) = item.state else { return }
        Task {
            do {
                try await MessageRepo.delete(messageId: message.id)
                items.removeAll { $0.id == message.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sendOptimistic(
        kind: MessageKind,
        body: String?,
        image: UIImage?,
        sharedWithCustomer: Bool,
        operation: @escaping () async throws -> UUID
    ) {
        let localId = UUID()
        var item = Item(
            state: .sending(localId: localId),
            body: body,
            kind: kind,
            senderId: profile.id,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            sharedWithCustomer: sharedWithCustomer
        )
        item.localImage = image
        items.append(item)

        let attempt: () -> Void = { [weak self] in
            guard let self else { return }
            // Ignore a retry while a send for this localId is already running,
            // so rapid taps can't fire duplicate uploads / send_message RPCs.
            guard !self.inFlightSends.contains(localId) else { return }
            self.inFlightSends.insert(localId)
            Task {
                defer { self.inFlightSends.remove(localId) }
                do {
                    let messageId = try await operation()
                    self.items.removeAll { $0.id == localId }
                    self.retryClosures[localId] = nil
                    // Merge the confirmed message directly; the realtime
                    // insert (if it also arrives) dedupes by id.
                    if let sent = try? await MessageRepo.message(id: messageId) {
                        await self.mergeIncoming(sent)
                    }
                } catch {
                    if let index = self.items.firstIndex(where: { $0.id == localId }) {
                        let retry: () -> Void = { [weak self] in
                            if let index = self?.items.firstIndex(where: { $0.id == localId }) {
                                self?.items[index].state = .sending(localId: localId)
                            }
                            self?.retryClosures[localId]?()
                        }
                        self.items[index].state = .failed(localId: localId, retry: retry)
                    }
                }
            }
        }
        retryClosures[localId] = attempt
        attempt()
    }

    private var retryClosures: [UUID: () -> Void] = [:]
    private var inFlightSends: Set<UUID> = []
}
