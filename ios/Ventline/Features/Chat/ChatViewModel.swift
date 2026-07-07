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
        /// Local preview for optimistic photo sends.
        var localImage: UIImage?
    }

    let projectId: UUID
    let taskId: UUID?
    let profile: Profile

    private(set) var items: [Item] = []
    private(set) var isLoading = false
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
        if id == profile.id { return "You" }
        return senderCache[id]?.fullName ?? "Teammate"
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

    func loadOlder() async {
        guard let oldest = items.first(where: {
            if case .sent = $0.state { return true } else { return false }
        })?.createdAt else { return }
        do {
            let older = try await MessageRepo.page(projectId: projectId, taskId: taskId, before: oldest)
            canLoadOlder = older.count >= MessageRepo.pageSize
            let hydrated = try await hydrate(older)
            items.insert(contentsOf: hydrated, at: 0)
            await loadSenders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hydrate(_ messages: [Message]) async throws -> [Item] {
        let attachments = try await MessageRepo.attachments(messageIds: messages.map(\.id))
        let annotations = try await MessageRepo.annotations(attachmentIds: attachments.map(\.id))
        var newestAnnotation: [UUID: PhotoAnnotation] = [:]
        for annotation in annotations.reversed() {
            newestAnnotation[annotation.attachmentId] = annotation
        }
        return messages.map { message in
            let mine = attachments.filter { $0.messageId == message.id }
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
                }
            )
        }
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
            await channel.subscribe()
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

    func sendText(_ text: String, sharedWithCustomer: Bool) {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        sendOptimistic(kind: .text, body: body, image: nil, sharedWithCustomer: sharedWithCustomer) {
            try await MessageRepo.send(
                projectId: self.projectId, taskId: self.taskId,
                kind: .text, body: body, sharedWithCustomer: sharedWithCustomer
            )
        }
    }

    func sendPhoto(_ image: UIImage, caption: String?, sharedWithCustomer: Bool) {
        sendOptimistic(kind: .photo, body: caption, image: image, sharedWithCustomer: sharedWithCustomer) {
            let uploaded = try await MediaUploader.uploadPhoto(
                image, companyId: self.profile.companyId, projectId: self.projectId
            )
            return try await MessageRepo.send(
                projectId: self.projectId, taskId: self.taskId,
                kind: .photo, body: caption,
                attachments: [uploaded.attachmentPayload],
                sharedWithCustomer: sharedWithCustomer
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
            Task {
                do {
                    let messageId = try await operation()
                    self.items.removeAll { $0.id == localId }
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
}
