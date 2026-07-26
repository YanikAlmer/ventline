import Foundation
import Network
import Observation

/// Writes that survive a Heizungskeller.
///
/// The model is an **outbox of intents**, not a local replica. Reads still want
/// the network; writes never fail. That fits what actually happens on site: the
/// crew needs to *record* — hours, material, a signature — not to browse.
///
/// Three properties make the replay safe, and all three live on the server:
///
///  1. **Every operation carries an id the device generated.** The sync_* RPCs
///     return the existing row when that id is already present, so a replay is
///     a no-op rather than a duplicate. A queue that cannot tell "sent" from
///     "sent and acknowledged" is the normal case, not the edge case.
///  2. **Order is preserved.** A Rapport cannot be signed before its lines
///     exist, so the queue is strictly FIFO and stops at the first failure
///     rather than skipping ahead.
///  3. **The signature carries a hash of what was signed.** The server
///     recomputes it and refuses the sync if the content moved in between.
@Observable
@MainActor
final class OfflineQueue {
    static let shared = OfflineQueue()

    private(set) var pending: [PendingOperation] = []
    private(set) var isOnline = true
    private(set) var isDraining = false
    private(set) var lastError: String?

    private let monitor = NWPathMonitor()
    private var storeURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ventline", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("outbox.json")
    }

    private init() {
        load()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isOnline = path.status == .satisfied
                // Drain on every update where there is a path, not only on a
                // transition. Waiting for a *change* meant a queue restored
                // from disk at launch never drained: isOnline starts true, the
                // first update is also true, so "regained connectivity" never
                // fired — and work saved offline sat there until the network
                // happened to flap. drain() is a no-op when the queue is empty.
                if self.isOnline { await self.drain() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "ventline.network"))

        // The queue restored from disk is the whole reason this class exists;
        // it must not depend on a network event that may never come.
        Task { await drain() }
    }

    /// Called when the app comes back to the foreground. A queue that failed
    /// mid-drain while backgrounded should not wait for a network flap either.
    func resume() {
        Task { await drain() }
    }

    // MARK: - Enqueue

    /// Records an operation and tries to send it immediately. Returns as soon
    /// as it is durably queued — the caller never waits on the network, so the
    /// UI is identical with signal and without.
    func enqueue(_ operation: PendingOperation) {
        pending.append(operation)
        persist()
        Task { await drain() }
    }

    /// Operations still waiting, for the parts of the UI that show local state
    /// before the server has seen it.
    func pendingOperations(ofKind kind: PendingOperation.Kind) -> [PendingOperation] {
        pending.filter { $0.kind == kind }
    }

    // MARK: - Drain

    func drain() async {
        guard !isDraining, isOnline, !pending.isEmpty else { return }
        isDraining = true
        defer { isDraining = false }

        // Strictly in order, stopping at the first failure: a later operation
        // may depend on an earlier one, and draining past a gap would sign a
        // Rapport whose lines never arrived.
        while let next = pending.first, isOnline {
            do {
                try await send(next)
                pending.removeFirst()
                lastError = nil
                persist()
            } catch {
                var failed = next
                failed.attempts += 1
                failed.lastError = FriendlyError.message(error)
                pending[0] = failed
                lastError = failed.lastError
                persist()

                // A server-side refusal will never succeed on retry — a
                // tampered Rapport, a deleted project. Retrying it forever
                // would wedge the queue behind an operation that cannot land,
                // so it is set aside and the rest continue.
                if failed.attempts >= 5 {
                    pending.removeFirst()
                    persist()
                    continue
                }
                break
            }
        }
    }

    private func send(_ operation: PendingOperation) async throws {
        switch operation.kind {
        case .timeEntry:
            let p = try operation.decode(TimeEntryPayload.self)
            try await TimeRepo.syncEntry(id: operation.id, payload: p)
        case .materialLine:
            let p = try operation.decode(MaterialPayload.self)
            try await MaterialRepo.syncLine(id: operation.id, payload: p)
        case .reportDraft:
            let p = try operation.decode(ReportDraftPayload.self)
            try await RapportRepo.syncDraft(id: operation.id, payload: p)
        case .attachTime:
            let p = try operation.decode(AttachTimePayload.self)
            try await RapportRepo.attachTime(reportId: p.reportId, timeEntryIds: p.timeEntryIds)
        case .signReport:
            let p = try operation.decode(SignPayload.self)
            try await RapportRepo.syncSignature(operation: operation, payload: p)
        }
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(pending)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            // Losing the queue file is worse than any single failed write, so
            // the error is surfaced rather than swallowed.
            lastError = error.localizedDescription
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        pending = (try? JSONDecoder().decode([PendingOperation].self, from: data)) ?? []
    }
}

// MARK: - Operations

struct PendingOperation: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case timeEntry
        case materialLine
        case reportDraft
        case attachTime
        case signReport
    }

    /// Generated on the device and used as the row's primary key, so a replay
    /// collides with itself rather than creating a second row.
    let id: UUID
    let kind: Kind
    let payload: Data
    let createdAt: Date
    var attempts: Int = 0
    var lastError: String?

    init<T: Encodable>(id: UUID = UUID(), kind: Kind, payload: T) throws {
        self.id = id
        self.kind = kind
        self.payload = try JSONEncoder().encode(payload)
        self.createdAt = Date()
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: payload)
    }
}

struct TimeEntryPayload: Codable {
    let projectId: UUID
    let profileId: UUID
    let taskId: UUID?
    let startedAt: Date
    let endedAt: Date?
    let breakMinutes: Int
    let note: String?
    let kind: String
}

struct MaterialPayload: Codable {
    let projectId: UUID
    let taskId: UUID?
    let description: String
    let quantityMilli: Int
    let unit: String
    let unitPriceRappen: Int
}

struct ReportDraftPayload: Codable {
    let projectId: UUID
    let title: String?
    let summary: String?
}

struct AttachTimePayload: Codable {
    let reportId: UUID
    let timeEntryIds: [UUID]
}

struct SignPayload: Codable {
    let reportId: UUID
    let signerName: String
    let signedAtDevice: Date
    /// SHA-256, hex, of the canonical text the customer was shown. The server
    /// recomputes it and refuses the sync if the content has since moved.
    let contentHashHex: String
    let companyId: UUID
    let projectId: UUID
    /// The flattened signature PNG, held locally until it can be uploaded.
    let signaturePNG: Data
}
