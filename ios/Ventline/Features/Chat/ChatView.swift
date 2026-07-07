import SwiftUI

/// Self-contained chat screen (used for project-level threads). Task threads
/// embed ChatViewBody directly inside TaskDetailView.
struct ChatView: View {
    @State private var model: ChatViewModel

    init(projectId: UUID, taskId: UUID?, profile: Profile) {
        _model = State(initialValue: ChatViewModel(projectId: projectId, taskId: taskId, profile: profile))
    }

    var body: some View {
        ChatViewBody(model: model)
            .task {
                await model.loadInitial()
                model.startRealtime()
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
