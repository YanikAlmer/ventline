import PhotosUI
import SwiftUI

/// Site photos on a Rapport.
///
/// For a trades document these are not decoration: "the old unit looked like
/// this, here is the new one in place" is most of what a customer is actually
/// signing off. The renderer has always printed them and the canonical text has
/// always covered their storage paths — nothing wrote the rows.
///
/// Two rules shape the interaction, and both come from the database:
///
///  1. **Photos go on a draft only.** report_photos is frozen the moment the
///     Rapport leaves 'draft', because the photos are part of what was signed.
///     So the section is read-only once signed, rather than offering an action
///     the server would refuse.
///
///  2. **Adding one needs a connection.** Everything else on a Rapport queues
///     offline, and a photo deliberately does not. The signature attests to a
///     hash of the canonical text, which *includes* the photo paths: a photo
///     sitting in the outbox would change that text after the customer had
///     already signed the version without it, and the sync would then refuse
///     the signature — failing at the worst possible moment for the right
///     reason. Better to say so up front.
struct RapportPhotosSection: View {
    let reportId: UUID
    let projectId: UUID
    let profile: Profile
    let isDraft: Bool
    @Binding var photos: [Attachment]

    @State private var picked: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var isUploading = false
    @State private var preview: Attachment?
    @State private var errorMessage: String?
    @State private var queue = OfflineQueue.shared

    var body: some View {
        Section {
            if photos.isEmpty && !isDraft {
                Text("No photos on this Rapport.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos, id: \.id) { photo in
                            Button { preview = photo } label: {
                                RapportPhotoThumb(attachment: photo)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if isDraft {
                                    Button(role: .destructive) {
                                        remove(photo)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if isDraft {
                if queue.isOnline {
                    PhotosPicker(
                        selection: $picked,
                        maxSelectionCount: 10,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Add from library", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isUploading)

                    Button {
                        showCamera = true
                    } label: {
                        Label("Take photo", systemImage: "camera")
                    }
                    .disabled(isUploading)
                } else {
                    Label("Photos need a connection", systemImage: "wifi.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isUploading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Uploading…").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("Photos")
        } footer: {
            if isDraft {
                Text("Photos are part of what the customer signs, so they cannot be added or removed afterwards.")
            }
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            upload(items)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture { image in
                showCamera = false
                guard let image else { return }
                upload(images: [image])
            }
        }
        .sheet(item: $preview) { photo in
            RapportPhotoPreview(attachment: photo)
        }
    }

    private func upload(_ items: [PhotosPickerItem]) {
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            picked = []
            upload(images: images)
        }
    }

    private func upload(images: [UIImage]) {
        guard !images.isEmpty else { return }
        isUploading = true
        errorMessage = nil
        Task {
            defer { isUploading = false }
            for image in images {
                do {
                    let media = try await MediaUploader.uploadPhoto(
                        image, companyId: profile.companyId, projectId: projectId)
                    let row = try await RapportRepo.addPhoto(
                        reportId: reportId, media: media, sortOrder: photos.count)
                    photos.append(row)
                } catch {
                    errorMessage = FriendlyError.message(error)
                    // Stop at the first failure rather than grinding through
                    // nine more uploads that will fail the same way.
                    return
                }
            }
        }
    }

    private func remove(_ photo: Attachment) {
        Task {
            do {
                if try await RapportRepo.removePhoto(
                    reportId: reportId, attachmentId: photo.id
                ) {
                    photos.removeAll { $0.id == photo.id }
                } else {
                    errorMessage = String(localized: "This photo could not be removed.")
                }
            } catch {
                errorMessage = FriendlyError.message(error)
            }
        }
    }
}

private struct RapportPhotoThumb: View {
    let attachment: Attachment
    @State private var url: URL?

    var body: some View {
        ZStack {
            if let url {
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
                bucket: attachment.storageBucket, path: attachment.storagePath)
        }
    }
}

private struct RapportPhotoPreview: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let url {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            url = try? await SignedURLCache.shared.url(
                bucket: attachment.storageBucket, path: attachment.storagePath)
        }
    }
}

/// The system camera. A jobsite photo is usually taken on the spot rather than
/// picked from a library that does not have it yet.
struct CameraCapture: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Falls back to the library on a simulator, which has no camera.
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
