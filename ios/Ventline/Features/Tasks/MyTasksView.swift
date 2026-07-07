import SwiftUI

struct MyTasksView: View {
    let profile: Profile

    @State private var tasks: [JobTask] = []
    @State private var isLoading = true

    private var open: [JobTask] {
        tasks.filter { $0.status != .approved && $0.status != .done }
    }
    private var finished: [JobTask] {
        tasks.filter { $0.status == .approved || $0.status == .done }
    }

    var body: some View {
        List {
            if isLoading && tasks.isEmpty {
                ProgressView()
            } else if tasks.isEmpty {
                ContentUnavailableView(
                    "Nothing assigned",
                    systemImage: "checklist",
                    description: Text("Tasks assigned to you will show up here.")
                )
            } else {
                if !open.isEmpty {
                    Section("Open") {
                        ForEach(open, id: \.id) { task in
                            NavigationLink {
                                TaskDetailView(taskId: task.id, profile: profile)
                            } label: {
                                TaskRow(task: task)
                            }
                        }
                    }
                }
                if !finished.isEmpty {
                    Section("Finished") {
                        ForEach(finished, id: \.id) { task in
                            NavigationLink {
                                TaskDetailView(taskId: task.id, profile: profile)
                            } label: {
                                TaskRow(task: task)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("My Tasks")
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        do {
            tasks = try await TaskRepo.myTasks(userId: profile.id)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}
