import AVKit
import PhotosUI
import SwiftUI

/// Photos and videos attached to the work itself rather than to a chat
/// message — the plan, the nameplate, the "how it looked before" clip. They
/// stay with the task instead of scrolling away with the conversation.
struct TaskFilesView: View {
    let task: JobTask
    let profile: Profile

    @State private var attachments: [Attachment] = []
    @State private var picked: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var preview: Attachment?

    private var canEdit: Bool { profile.role != .customer }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Files")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(attachments.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                if canEdit {
                    PhotosPicker(
                        selection: $picked,
                        maxSelectionCount: 5,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Label("Photo or video", systemImage: "photo.badge.plus")
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(isUploading)
                }
            }

            if attachments.isEmpty, !isUploading {
                Text("No photos or videos on this task yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments, id: \.id) { attachment in
                            Button {
                                preview = attachment
                            } label: {
                                AttachmentThumb(attachment: attachment)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if canDelete(attachment) {
                                    Button(role: .destructive) {
                                        delete(attachment)
                                    } label: {
                                        Label("Delete file", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        if isUploading {
                            ProgressView()
                                .frame(width: 84, height: 84)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task { await load() }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            upload(items)
        }
        .sheet(item: $preview) { attachment in
            AttachmentPreview(attachment: attachment)
        }
    }

    private func canDelete(_ attachment: Attachment) -> Bool {
        canEdit && (attachment.uploadedBy == profile.id || profile.role.isOffice)
    }

    private func load() async {
        attachments = (try? await TaskRepo.attachments(taskId: task.id)) ?? []
    }

    private func upload(_ items: [PhotosPickerItem]) {
        isUploading = true
        errorMessage = nil
        Task {
            defer {
                isUploading = false
                picked = []
            }
            for item in items {
                do {
                    let media: MediaUploader.Uploaded
                    if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                        // Videos arrive as a file rather than raw Data: a 200 MB
                        // clip held in memory is how a jobsite phone gets killed.
                        guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                            continue
                        }
                        defer { try? FileManager.default.removeItem(at: movie.url) }
                        media = try await MediaUploader.uploadVideo(
                            fileURL: movie.url,
                            companyId: profile.companyId,
                            projectId: task.projectId
                        )
                    } else {
                        guard let data = try await item.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else { continue }
                        media = try await MediaUploader.uploadPhoto(
                            image,
                            companyId: profile.companyId,
                            projectId: task.projectId
                        )
                    }
                    let row = try await TaskRepo.addAttachment(taskId: task.id, media: media)
                    attachments.append(row)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func delete(_ attachment: Attachment) {
        Task {
            do {
                // RLS answers a forbidden delete with zero rows, not an error,
                // so only drop it from the list when the row really went.
                let removed = try await TaskRepo.deleteAttachment(id: attachment.id)
                if removed {
                    attachments.removeAll { $0.id == attachment.id }
                } else {
                    errorMessage = String(
                        localized: "Only the person who uploaded a file, or the office, can delete it."
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// PhotosPicker hands videos over as a file. Copying it out of the temporary
/// location it arrives in is required: the system reclaims that URL.
private struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension.isEmpty
                    ? "mov" : received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

private struct AttachmentThumb: View {
    let attachment: Attachment
    @State private var url: URL?

    var body: some View {
        ZStack {
            if attachment.kind == .video {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.85))
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            } else if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.secondarySystemBackground)
                }
            } else {
                Color(.secondarySystemBackground)
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task {
            url = try? await SignedURLCache.shared.url(
                bucket: attachment.storageBucket, path: attachment.storagePath
            )
        }
    }
}

private struct AttachmentPreview: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let url {
                    if attachment.kind == .video {
                        VideoPlayer(player: AVPlayer(url: url))
                    } else {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            url = try? await SignedURLCache.shared.url(
                bucket: attachment.storageBucket, path: attachment.storagePath
            )
        }
    }
}
