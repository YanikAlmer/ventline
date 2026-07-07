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

    var body: some View {
        VStack(spacing: 8) {
            if let pendingPhoto {
                pendingPhotoPreview(pendingPhoto)
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

    private func send() {
        let caption = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let photo = pendingPhoto {
            model.sendPhoto(photo, caption: caption.isEmpty ? nil : caption, sharedWithCustomer: shareWithCustomer)
            pendingPhoto = nil
        } else {
            model.sendText(caption, sharedWithCustomer: shareWithCustomer)
        }
        text = ""
        shareWithCustomer = false
    }
}
