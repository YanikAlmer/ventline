import AVFoundation
import PhotosUI
import SwiftUI

struct ComposerBar: View {
    let model: ChatViewModel

    @State private var text = ""
    @State private var shareWithCustomer = false
    @State private var mediaItem: PhotosPickerItem?
    /// One slot, not two optionals: a photo and a video can never both be
    /// staged, and two optionals make that a rule you have to remember.
    @State private var pendingMedia: PendingMedia?
    @State private var mediaError: String?
    @State private var showVoiceRecorder = false
    @FocusState private var focused: Bool

    /// What has been picked, not where it sits: offsets are derived from the
    /// final text at send time, so editing around a mention cannot
    /// desynchronise a range nobody can see.
    @State private var pending: [Annotations.Pending] = []
    @State private var trigger: Annotations.Trigger?
    @State private var people: [MessageRepo.MentionCandidate] = []
    @State private var tasks: [MessageRepo.TaskRefCandidate] = []
    @State private var suggestionToken = ""

    var body: some View {
        VStack(spacing: 8) {
            if let pendingMedia {
                pendingMediaPreview(pendingMedia)
            }
            if let mediaError {
                Text(mediaError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Above the field: on a phone the keyboard owns everything below.
            if trigger != nil, hasSuggestions {
                suggestionStrip
            }

            HStack(alignment: .bottom, spacing: 10) {
                PhotosPicker(
                    selection: $mediaItem,
                    matching: .any(of: [.images, .videos])
                ) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                }

                Button {
                    showVoiceRecorder = true
                } label: {
                    Image(systemName: "mic")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                }

                TextField(pendingMedia == nil ? "Message" : "Add a caption…", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .autocorrectionDisabled(trigger != nil)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .focused($focused)

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingMedia == nil)
            }

            Toggle(isOn: $shareWithCustomer) {
                Label("Visible to customer", systemImage: "eye")
                    .font(.footnote)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(.teal)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .onChange(of: text) {
            // UITextField's caret is not reachable from a SwiftUI TextField, so
            // the trigger is read from the end of the text. That covers typing,
            // which is how every mention is actually written; going back to
            // edit an earlier word simply does not reopen the picker.
            trigger = Annotations.trigger(in: text, caret: text.utf16.count)
        }
        .task(id: trigger) {
            guard let trigger else { return }
            // Debounced. Someone typing "@Wanda" would otherwise fire six
            // queries and only the last answer is still on screen.
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await loadSuggestions(for: trigger)
        }
        .onChange(of: mediaItem) {
            guard let mediaItem else { return }
            Task {
                await stage(mediaItem)
                self.mediaItem = nil
            }
        }
        .sheet(isPresented: $showVoiceRecorder) {
            VoiceRecorderSheet { fileURL, duration in
                model.sendVoice(fileURL: fileURL, duration: duration)
            }
            .presentationDetents([.height(220)])
        }
    }

    private func pendingMediaPreview(_ media: PendingMedia) -> some View {
        HStack {
            ZStack {
                if let thumbnail = media.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.tertiarySystemFill)
                }
                if case .video = media {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(media.label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                media.discard()
                pendingMedia = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Staging a photo or a video

    /// Imports the picked item and checks it *before* it looks ready to send.
    ///
    /// The size and type limits are enforced server-side by the bucket and
    /// again inside MediaUploader, but finding out there means the person taps
    /// send, waits through an upload, and then gets a red row. Checking here
    /// costs one file-size read and turns a failed send into a refusal at the
    /// moment of choosing.
    private func stage(_ item: PhotosPickerItem) async {
        mediaError = nil
        let isMovie = item.supportedContentTypes.contains { $0.conforms(to: .movie) }

        if isMovie {
            guard let movie = try? await item.loadTransferable(type: PickedMovie.self) else {
                mediaError = String(localized: "That video could not be read.")
                return
            }
            let size = (try? movie.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= MediaUploader.maxVideoBytes else {
                try? FileManager.default.removeItem(at: movie.url)
                mediaError = String(
                    localized: "That video is too large. The limit is 200 MB.")
                return
            }
            pendingMedia = .video(movie.url, thumbnail: await Self.frame(from: movie.url))
        } else {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                mediaError = String(localized: "That photo could not be read.")
                return
            }
            pendingMedia = .photo(image)
        }
    }

    /// First frame, for the staged-video preview. Best effort — a clip whose
    /// first frame will not decode is still perfectly sendable.
    private static func frame(from url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)
        guard let cg = try? await generator.image(at: .zero).image else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Mentions and references

    private var hasSuggestions: Bool { !people.isEmpty || !tasks.isEmpty }

    private var suggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(people) { person in
                    suggestionChip(
                        title: "@\(person.fullName)",
                        subtitle: person.isMember ? nil : String(localized: "Office")
                    ) {
                        choose(kind: .mention, id: person.profileId, text: "@\(person.fullName)")
                    }
                }
                ForEach(tasks) { task in
                    suggestionChip(
                        title: "#\(task.title)",
                        subtitle: task.parentTitle
                    ) {
                        choose(kind: .task, id: task.taskId, text: "#\(task.title)")
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxHeight: 46)
    }

    private func suggestionChip(
        title: String, subtitle: String?, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func loadSuggestions(for trigger: Annotations.Trigger) async {
        let token = trigger.sigil.rawValue + trigger.query
        switch trigger.sigil {
        case .mention:
            let rows = (try? await MessageRepo.mentionCandidates(
                projectId: model.projectId, query: trigger.query)) ?? []
            // Stamped with the token they answer: without it a new "@..."
            // shows the previous list for the length of the debounce, which is
            // long enough to tap the wrong person.
            guard self.trigger.map({ $0.sigil.rawValue + $0.query }) == token else { return }
            people = rows
            tasks = []
        case .task:
            let rows = (try? await MessageRepo.taskRefCandidates(
                projectId: model.projectId, query: trigger.query)) ?? []
            guard self.trigger.map({ $0.sigil.rawValue + $0.query }) == token else { return }
            tasks = rows
            people = []
        }
        suggestionToken = token
    }

    private func choose(kind: Annotations.Pending.Kind, id: UUID, text chosen: String) {
        guard let trigger else { return }
        let result = Annotations.apply(trigger: trigger, choosing: chosen, in: text)
        text = result.body
        pending.append(Annotations.Pending(kind: kind, id: id, text: chosen))
        self.trigger = nil
        people = []
        tasks = []
    }

    private func send() {
        let caption = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch pendingMedia {
        case .photo(let image):
            model.sendPhoto(
                image, caption: caption.isEmpty ? nil : caption,
                sharedWithCustomer: shareWithCustomer, pending: pending)
            pendingMedia = nil
        case .video(let url, _):
            model.sendVideo(
                fileURL: url, caption: caption.isEmpty ? nil : caption,
                sharedWithCustomer: shareWithCustomer, pending: pending)
            pendingMedia = nil
        case .none:
            model.sendText(caption, sharedWithCustomer: shareWithCustomer, pending: pending)
        }
        text = ""
        pending = []
        trigger = nil
        people = []
        tasks = []
        shareWithCustomer = false
    }
}

/// What is staged in the composer, waiting for a caption and a send.
enum PendingMedia {
    case photo(UIImage)
    case video(URL, thumbnail: UIImage?)

    var thumbnail: UIImage? {
        switch self {
        case .photo(let image): image
        case .video(_, let thumbnail): thumbnail
        }
    }

    var label: String {
        switch self {
        case .photo: String(localized: "Photo ready to send")
        case .video: String(localized: "Video ready to send")
        }
    }

    /// Drops the temp file when a staged video is dismissed unsent. Without
    /// this, picking and discarding three clips leaves 600 MB in tmp.
    func discard() {
        if case .video(let url, _) = self {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
