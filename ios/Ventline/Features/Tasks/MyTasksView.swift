import SwiftUI

struct MyTasksView: View {
    let profile: Profile

    @State private var tasks: [JobTask] = []
    /// Package titles for the steps in the list. Without this a step reads as
    /// "Kondensatpumpe montieren" with no clue which job it belongs to —
    /// exactly the mix-up this screen has to avoid for someone on five sites.
    @State private var packageTitles: [UUID: String] = [:]
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
                                MyTaskRow(
                                    task: task,
                                    packageTitle: task.parentId.flatMap { packageTitles[$0] }
                                )
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
                                MyTaskRow(
                                    task: task,
                                    packageTitle: task.parentId.flatMap { packageTitles[$0] }
                                )
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
            let parentIds = Set(tasks.compactMap(\.parentId))
            if !parentIds.isEmpty {
                let packages = (try? await TaskRepo.tasks(ids: Array(parentIds))) ?? []
                packageTitles = Dictionary(
                    uniqueKeysWithValues: packages.map { ($0.id, $0.title) }
                )
            } else {
                packageTitles = [:]
            }
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

/// A "My Tasks" row: like TaskRow, but a step also names its work package.
struct MyTaskRow: View {
    let task: JobTask
    let packageTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let packageTitle {
                Label(packageTitle, systemImage: "shippingbox")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            TaskRow(task: task)
        }
    }
}
