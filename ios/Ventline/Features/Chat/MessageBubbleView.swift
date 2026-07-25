import SwiftUI

struct MessageBubbleView: View {
    let item: ChatViewModel.Item
    let model: ChatViewModel

    private var isMine: Bool { item.senderId == model.profile.id }

    var body: some View {
        if item.kind == .system {
            systemRow
        } else {
            bubbleRow
        }
    }

    private var systemRow: some View {
        // Composed verbatim because both halves are already resolved strings:
        // the sender name is user data and the body is localized above.
        Text(verbatim: "\(model.senderFullName(item.senderId)) \(localizedSystemBody(item.body ?? ""))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 2)
    }

    private var bubbleRow: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    Text(model.senderName(item.senderId))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let image = item.localImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 240, maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .opacity(0.7)
                    }

                    ForEach(item.attachments, id: \.id) { attachment in
                        AttachmentView(
                            attachment: attachment,
                            annotation: item.annotationsByAttachment[attachment.id],
                            model: model
                        )
                    }

                    if let body = item.body, !body.isEmpty {
                        Text(body)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isMine ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 6) {
                    stateFooter
                    if item.sharedWithCustomer {
                        Label("Customer", systemImage: "eye")
                            .font(.caption2)
                            .foregroundStyle(.teal)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .contextMenu {
                if isMine || model.profile.role.isOffice {
                    Button(role: .destructive) {
                        model.deleteMessage(item)
                    } label: {
                        Label("Delete message", systemImage: "trash")
                    }
                }
            }

            if !isMine { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private var stateFooter: some View {
        switch item.state {
        case .sent:
            Text(Timestamps.time(item.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .sending:
            Label("Sending…", systemImage: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .failed(_, let retry):
            Button {
                retry()
            } label: {
                Label("Failed — tap to retry", systemImage: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// Photo (with annotation overlay swap) or voice attachment content.
struct AttachmentView: View {
    let attachment: Attachment
    let annotation: PhotoAnnotation?
    let model: ChatViewModel

    @State private var showMarkup = false

    var body: some View {
        switch attachment.kind {
        case .photo:
            photoBody
        case .voice:
            AudioPlayerView(attachment: attachment)
        case .video:
            // Milestone 2.
            Label("Video message", systemImage: "video")
                .foregroundStyle(.secondary)
        }
    }

    private var photoBody: some View {
        // Show the annotated render when someone has marked the photo up.
        let bucket = annotation != nil ? "photos" : attachment.storageBucket
        let path = annotation?.renderedPath ?? attachment.storagePath

        return StorageImage(bucket: bucket, path: path)
            .frame(maxWidth: 240, maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                if annotation != nil {
                    Image(systemName: "pencil.tip.crop.circle.badge.plus")
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(6)
                }
            }
            .onTapGesture { showMarkup = true }
            .fullScreenCover(isPresented: $showMarkup) {
                PhotoMarkupView(attachment: attachment, model: model, annotation: annotation)
            }
    }
}

/// Async image from a private storage bucket via cached signed URLs.
struct StorageImage: View {
    let bucket: String
    let path: String

    @State private var url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder(icon: "photo.badge.exclamationmark")
                    default:
                        ProgressView()
                    }
                }
            } else {
                placeholder(icon: "photo")
            }
        }
        .task(id: path) {
            url = try? await SignedURLCache.shared.url(bucket: bucket, path: path)
        }
    }

    private func placeholder(icon: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.tertiarySystemFill))
            .frame(width: 200, height: 150)
            .overlay(Image(systemName: icon).foregroundStyle(.secondary))
    }
}
