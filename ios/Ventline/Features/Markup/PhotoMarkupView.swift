import PencilKit
import Supabase
import SwiftUI

/// Draw on a photo attachment. Saves BOTH:
///  - the vector strokes (PKDrawing, transformed into image-pixel space) so
///    markup can be re-opened and extended on iOS, and
///  - a flattened JPEG render so web and the customer portal can display the
///    annotated photo without any canvas code.
struct PhotoMarkupView: View {
    let attachment: Attachment
    let model: ChatViewModel
    var annotation: PhotoAnnotation?

    @Environment(\.dismiss) private var dismiss
    @State private var original: UIImage?
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var isSaving = false
    @State private var loadError = false

    var body: some View {
        NavigationStack {
            Group {
                if let original {
                    GeometryReader { geo in
                        let display = displaySize(image: original.size, in: geo.size)
                        ZStack {
                            Color(.systemBackground).ignoresSafeArea()
                            Image(uiImage: original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: display.width, height: display.height)
                                .overlay(
                                    MarkupCanvas(
                                        canvasView: canvasView,
                                        toolPicker: toolPicker,
                                        existingDrawing: existingDrawing(displaySize: display, imageSize: original.size)
                                    )
                                    .frame(width: display.width, height: display.height)
                                )
                                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        }
                    }
                } else if loadError {
                    ContentUnavailableView("Couldn't load photo", systemImage: "photo.badge.exclamationmark")
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Mark up photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .disabled(original == nil)
                    }
                }
            }
            .task { await loadOriginal() }
        }
    }

    private func displaySize(image: CGSize, in container: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return container }
        let scale = min(container.width / image.width, container.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }

    private func loadOriginal() async {
        do {
            let data = try await Supa.client.storage
                .from(attachment.storageBucket)
                .download(path: attachment.storagePath)
            if let image = UIImage(data: data) {
                original = image
            } else {
                loadError = true
            }
        } catch {
            loadError = true
        }
    }

    /// Stored strokes are in image-pixel space; scale them to the display
    /// canvas so editing continues where it left off.
    private func existingDrawing(displaySize: CGSize, imageSize: CGSize) -> PKDrawing? {
        guard
            let annotation,
            case .object(let object) = annotation.drawingData,
            case .string(let base64)? = object["pkdrawing_base64"],
            let data = Data(base64Encoded: base64),
            let drawing = try? PKDrawing(data: data),
            imageSize.width > 0
        else { return nil }
        let scale = displaySize.width / imageSize.width
        return drawing.transformed(using: CGAffineTransform(scaleX: scale, y: scale))
    }

    private func save() {
        guard let original else { return }
        isSaving = true
        let displayBounds = canvasView.bounds
        let drawing = canvasView.drawing

        Task {
            do {
                let imageSize = original.size
                let toImageScale = displayBounds.width > 0 ? imageSize.width / displayBounds.width : 1

                // Strokes in image-pixel space (stored for later re-editing).
                let imageSpaceDrawing = drawing.transformed(
                    using: CGAffineTransform(scaleX: toImageScale, y: toImageScale)
                )

                // Flattened composite at full image resolution.
                let overlay = imageSpaceDrawing.image(
                    from: CGRect(origin: .zero, size: imageSize), scale: 1
                )
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                let composite = UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
                    original.draw(in: CGRect(origin: .zero, size: imageSize))
                    overlay.draw(in: CGRect(origin: .zero, size: imageSize))
                }

                guard let jpeg = composite.jpegData(compressionQuality: 0.85) else {
                    throw NSError(domain: "Ventline", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not render markup"])
                }

                // Rendered file lives next to the original: same folder,
                // "_annotated" suffix (storage policies key off the folder).
                let renderedPath = attachment.storagePath
                    .replacingOccurrences(of: ".jpg", with: "")
                    .appending("_annotated_\(UUID().uuidString.prefix(8)).jpg")
                try await Supa.client.storage.from("photos").upload(
                    renderedPath,
                    data: jpeg,
                    options: FileOptions(contentType: "image/jpeg")
                )

                let drawingData: [String: AnyJSON] = [
                    "format": .string("pencilkit-v1"),
                    "canvas": .object([
                        "w": .integer(Int(imageSize.width)),
                        "h": .integer(Int(imageSize.height)),
                    ]),
                    "pkdrawing_base64": .string(imageSpaceDrawing.dataRepresentation().base64EncodedString()),
                ]
                try await MessageRepo.saveAnnotation(
                    attachmentId: attachment.id,
                    authorId: model.profile.id,
                    drawingData: drawingData,
                    renderedPath: renderedPath
                )
                await model.loadInitial()
                dismiss()
            } catch {
                isSaving = false
                model.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct MarkupCanvas: UIViewRepresentable {
    let canvasView: PKCanvasView
    let toolPicker: PKToolPicker
    let existingDrawing: PKDrawing?

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .systemRed, width: 6)
        if let existingDrawing {
            canvasView.drawing = existingDrawing
        }
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        DispatchQueue.main.async {
            canvasView.becomeFirstResponder()
        }
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
