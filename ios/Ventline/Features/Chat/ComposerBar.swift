import PhotosUI
import SwiftUI

struct ComposerBar: View {
    let model: ChatViewModel

    @State private var text = ""
    @State private var shareWithCustomer = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingPhoto: UIImage?
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
            if let pendingPhoto {
                pendingPhotoPreview(pendingPhoto)
            }

            // Above the field: on a phone the keyboard owns everything below.
            if trigger != nil, hasSuggestions {
                suggestionStrip
            }

            HStack(alignment: .bottom, spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
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

                TextField(pendingPhoto == nil ? "Message" : "Add a caption…", text: $text, axis: .vertical)
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
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingPhoto == nil)
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
        .onChange(of: photoItem) {
            guard let photoItem else { return }
            Task {
                if let data = try? await photoItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pendingPhoto = image
                }
                self.photoItem = nil
            }
        }
        .sheet(isPresented: $showVoiceRecorder) {
            VoiceRecorderSheet { fileURL, duration in
                model.sendVoice(fileURL: fileURL, duration: duration)
            }
            .presentationDetents([.height(220)])
        }
    }

    private func pendingPhotoPreview(_ image: UIImage) -> some View {
        HStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("Photo ready to send")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                pendingPhoto = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        if let photo = pendingPhoto {
            model.sendPhoto(
                photo, caption: caption.isEmpty ? nil : caption,
                sharedWithCustomer: shareWithCustomer, pending: pending)
            pendingPhoto = nil
        } else {
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
