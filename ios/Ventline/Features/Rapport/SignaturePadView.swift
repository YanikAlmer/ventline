import PencilKit
import SwiftUI

/// The customer signs on the phone.
///
/// What this is, legally: a *simple* electronic signature under ZertES. That is
/// sufficient for a Rapport — an acknowledgement that work was performed is not
/// a contract requiring a qualified signature. Its evidentiary weight comes from
/// the surrounding record rather than from the drawing: who signed, when, and a
/// hash of the exact document they were shown. All three are captured by
/// sign_report on the server.
///
/// The strokes are flattened to a PNG here. The pressure/timing series that
/// PencilKit also has is deliberately NOT sent: its classification as
/// biometric data under revDSG is unresolved, and a raster is enough for what
/// this document needs to prove.
struct SignaturePadView: View {
    let reportTitle: String
    let onCancel: () -> Void
    let onSigned: (Data, String) async -> Void

    @State private var canvas = PKCanvasView()
    @State private var signerName = ""
    @State private var hasDrawn = false
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reportTitle)
                        .font(.headline)
                    Text("By signing you confirm that the work listed above was carried out.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                TextField("Name in block capitals", text: $signerName)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal)

                ZStack(alignment: .bottomLeading) {
                    SignatureCanvas(canvas: $canvas, hasDrawn: $hasDrawn)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    if !hasDrawn {
                        Text("Sign here")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 220)
                .padding(.horizontal)

                HStack {
                    Button("Clear") {
                        canvas.drawing = PKDrawing()
                        hasDrawn = false
                    }
                    .disabled(!hasDrawn)
                    Spacer()
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sign") { submit() }
                        .disabled(isWorking || !hasDrawn
                                  || signerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func submit() {
        isWorking = true
        Task {
            defer { isWorking = false }
            let bounds = canvas.bounds
            let image = canvas.drawing.image(from: bounds, scale: 2)
            // Flatten onto white: the drawing alone is transparent, which
            // prints as nothing on a white PDF page.
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            format.opaque = true
            let flattened = UIGraphicsImageRenderer(size: bounds.size, format: format).image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: bounds.size))
                image.draw(in: CGRect(origin: .zero, size: bounds.size))
            }
            guard let png = flattened.pngData() else { return }
            await onSigned(png, signerName.trimmingCharacters(in: .whitespaces))
        }
    }
}

private struct SignatureCanvas: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    @Binding var hasDrawn: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput   // a finger must work; not every crew has a stylus
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(hasDrawn: $hasDrawn) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let hasDrawn: Binding<Bool>
        init(hasDrawn: Binding<Bool>) { self.hasDrawn = hasDrawn }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            hasDrawn.wrappedValue = !canvasView.drawing.strokes.isEmpty
        }
    }
}
