import SwiftUI

/// Self-contained chat screen (used for project-level threads). Task threads
/// embed ChatViewBody directly inside TaskDetailView.
struct ChatView: View {
    @State private var model: ChatViewModel
    /// Set when the thread was opened from a search hit or the person lens.
    private let focusMessageId: UUID?

    init(projectId: UUID, taskId: UUID?, profile: Profile, focusMessageId: UUID? = nil) {
        _model = State(initialValue: ChatViewModel(projectId: projectId, taskId: taskId, profile: profile))
        self.focusMessageId = focusMessageId
    }

    var body: some View {
        ChatViewBody(model: model)
            .task {
                if let focusMessageId {
                    await model.loadAround(messageId: focusMessageId)
                } else {
                    await model.loadInitial()
                }
                model.startRealtime()
                await model.markRead()
            }
            .alert("Something went wrong", isPresented: .init(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
    }
}
