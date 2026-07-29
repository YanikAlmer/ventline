import AVKit
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
                        Text(annotatedBody(body))
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

    /// The body with its mentions and references picked out.
    ///
    /// Built as an AttributedString rather than a stack of Text views so the
    /// paragraph still wraps as one block — a message is a sentence, not a row
    /// of chips. A reference carries a `ventline://task/<id>` link the chat
    /// screen intercepts; SwiftUI renders and hit-tests it for free.
    private func annotatedBody(_ body: String) -> AttributedString {
        var out = AttributedString()
        for segment in Annotations.segments(body: body, annotations: item.textAnnotations) {
            switch segment {
            case .text(let run):
                out.append(AttributedString(run))
            case .mention(let run, let profileId):
                var piece = AttributedString(run)
                piece.font = .body.weight(.semibold)
                // Being mentioned yourself has to read differently from
                // watching someone else be mentioned.
                piece.foregroundColor = profileId == model.profile.id ? .orange : .accentColor
                out.append(piece)
            case .task(let run, let taskId):
                var piece = AttributedString(run)
                piece.font = .body.weight(.semibold)
                piece.link = URL(string: "ventline://task/\(taskId.uuidString.lowercased())")
                out.append(piece)
            }
        }
        return out
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
            VideoBubble(attachment: attachment)
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

/// A video in a thread: poster frame, duration, tap to play.
///
/// The poster is pulled from the signed URL rather than stored, because
/// AVAssetImageGenerator range-requests just enough of the file to decode one
/// frame — cheaper than uploading and keeping a second object per clip, and it
/// cannot fall out of sync with the video. Best effort: a clip whose first
/// frame will not decode still plays, it just shows the plain card.
private struct VideoBubble: View {
    let attachment: Attachment

    @State private var url: URL?
    @State private var poster: UIImage?
    @State private var isPlaying = false

    var body: some View {
        Button {
            isPlaying = true
        } label: {
            ZStack {
                if let poster {
                    Image(uiImage: poster)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Color.black.opacity(0.85))
                }

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)

                if let seconds = attachment.durationSeconds {
                    Text(Self.clock(seconds))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottomTrailing)
                }
            }
            .frame(width: 240, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
        .fullScreenCover(isPresented: $isPlaying) {
            if let url {
                VideoPlayerSheet(url: url)
            }
        }
        .task {
            url = try? await SignedURLCache.shared.url(
                bucket: attachment.storageBucket, path: attachment.storagePath)
            guard let url else { return }
            poster = await Self.poster(for: url)
        }
    }

    private static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func poster(for url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        guard let cg = try? await generator.image(at: .zero).image else { return nil }
        return UIImage(cgImage: cg)
    }
}

private struct VideoPlayerSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea(edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
