import SwiftUI

/// Put the steps of a work package in the order they will actually be worked.
///
/// A sheet rather than drag-to-reorder in place. `.onMove` needs a `List`, and
/// the steps live inside the task screen's scroll view alongside the chat —
/// nesting a List in a ScrollView gives two competing scroll gestures and a
/// drag that fights the page. Reordering is also a deliberate, occasional act,
/// not something done while reading, so a screen of its own costs nothing and
/// buys the native drag handles.
///
/// Nothing is saved until Done. The RPC rewrites every position atomically, so
/// a half-finished rearrangement never reaches the server, and a list that has
/// gone stale — someone added a step while this was open — is refused whole
/// rather than partly applied.
struct StepReorderSheet: View {
    let parentId: UUID
    let steps: [JobTask]
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var order: [JobTask] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(order, id: \.id) { step in
                        StepRow(step: step)
                    }
                    .onMove { source, destination in
                        order.move(fromOffsets: source, toOffset: destination)
                    }
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else {
                        Text("Drag to set the order the work is done in.")
                    }
                }
            }
            // Always on: an Edit button first would hide the only thing this
            // screen exists to do behind a second tap.
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Order steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }.disabled(isSaving)
                }
            }
        }
        .task { order = steps }
    }

    private func save() {
        // Unchanged order: nothing to write, and no reason to make the person
        // wait on a round trip to find that out.
        guard order.map(\.id) != steps.map(\.id) else {
            dismiss()
            return
        }
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await TaskRepo.reorderSteps(
                    parentId: parentId, orderedIds: order.map(\.id))
                await onSaved()
                dismiss()
            } catch {
                errorMessage = FriendlyError.message(error)
            }
        }
    }
}
