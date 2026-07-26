import SwiftUI

/// What the outbox is holding, when it is holding anything.
///
/// Deliberately quiet: with signal and an empty queue it renders nothing at
/// all. Offline work should feel like normal work, and a permanent "offline"
/// chip would just train people to ignore it.
struct SyncStatusSection: View {
    @State private var queue = OfflineQueue.shared

    var body: some View {
        if !queue.pending.isEmpty || !queue.isOnline {
            Section {
                HStack(spacing: 10) {
                    if queue.isDraining {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: queue.isOnline
                              ? "arrow.triangle.2.circlepath" : "wifi.slash")
                            .foregroundStyle(queue.isOnline ? Color.accentColor : .orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline)
                            .font(.subheadline.weight(.medium))
                        if let error = queue.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        } else {
                            Text("Everything is saved on this phone and will sync by itself.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var headline: String {
        if !queue.pending.isEmpty {
            return String(format: String(localized: "%lld waiting to sync"),
                          queue.pending.count)
        }
        return String(localized: "No connection")
    }
}

/// The same information as a slim bar, for screens that are not lists.
struct SyncBanner: View {
    @State private var queue = OfflineQueue.shared

    var body: some View {
        if !queue.pending.isEmpty || !queue.isOnline {
            HStack(spacing: 8) {
                Image(systemName: queue.isOnline ? "arrow.up.circle" : "wifi.slash")
                    .font(.caption)
                Text(queue.pending.isEmpty
                     ? String(localized: "No connection")
                     : String(format: String(localized: "%lld waiting to sync"),
                              queue.pending.count))
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(queue.isOnline
                        ? Color.accentColor.opacity(0.12)
                        : Color.orange.opacity(0.15))
        }
    }
}
