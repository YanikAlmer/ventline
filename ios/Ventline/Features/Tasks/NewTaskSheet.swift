import SwiftUI

struct NewTaskSheet: View {
    let projectId: UUID
    let profile: Profile
    let members: [Profile]
    let onCreated: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var visibleToCustomer = false
    @State private var assignees: Set<UUID> = []
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var assignableMembers: [Profile] {
        members.filter { $0.role != .customer }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title)
                    TextField("Details (optional)", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                    if profile.role.canManageTasks {
                        Toggle(isOn: $visibleToCustomer) {
                            Label("Visible to customer", systemImage: "eye")
                        }
                    }
                }

                if !assignableMembers.isEmpty {
                    Section("Assign to") {
                        ForEach(assignableMembers, id: \.id) { member in
                            Button {
                                if assignees.contains(member.id) {
                                    assignees.remove(member.id)
                                } else {
                                    assignees.insert(member.id)
                                }
                            } label: {
                                HStack {
                                    PersonRow(profile: member)
                                    Spacer()
                                    if assignees.contains(member.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(isWorking || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        isWorking = true
        Task {
            do {
                let due: String? = hasDueDate
                    ? dueDate.formatted(.iso8601.year().month().day())
                    : nil
                let task = try await TaskRepo.create(
                    projectId: projectId,
                    companyId: profile.companyId,
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: details.isEmpty ? nil : details,
                    dueDate: due,
                    visibleToCustomer: visibleToCustomer
                )
                for assignee in assignees {
                    try await TaskRepo.assign(taskId: task.id, profileId: assignee)
                }
                await onCreated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }
}
