import SwiftUI

/// Creates an Arbeitspaket, or — when `parent` is given — an Arbeitsschritt
/// inside it. The two differ in the parent they send and in their wording, not
/// in what the form collects.
struct NewTaskSheet: View {
    let projectId: UUID
    let profile: Profile
    let members: [Profile]
    var parent: JobTask?
    let onCreated: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var dueTime = Date()
    @State private var hasDueTime = false
    @State private var visibleToCustomer = false
    @State private var assignees: Set<UUID> = []
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var isStep: Bool { parent != nil }

    private var assignableMembers: [Profile] {
        members.filter { $0.role != .customer }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let parent {
                    Section {
                        Label(parent.title, systemImage: "shippingbox")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Step of")
                    }
                }

                Section {
                    TextField("What needs doing?", text: $title)
                    TextField("Details (optional)", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                        Toggle("At a set time", isOn: $hasDueTime)
                        if hasDueTime {
                            DatePicker("Time", selection: $dueTime, displayedComponents: .hourAndMinute)
                        }
                    }
                    if profile.role.canManageTasks {
                        Toggle(isOn: $visibleToCustomer) {
                            Label("Visible to customer", systemImage: "eye")
                        }
                        if isStep, visibleToCustomer, parent?.visibleToCustomer == false {
                            Text("The customer only sees this step if the work package is visible to them too.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            .navigationTitle(isStep ? "New step" : "New work package")
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

    /// Postgres `time` wants 24-hour "HH:mm" regardless of the device's clock
    /// preference, so this formatter is deliberately locale-independent.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private func create() {
        isWorking = true
        Task {
            do {
                let due: String? = hasDueDate
                    ? dueDate.formatted(.iso8601.year().month().day())
                    : nil
                let time: String? = hasDueDate && hasDueTime
                    ? Self.timeFormatter.string(from: dueTime)
                    : nil
                let task = try await TaskRepo.create(
                    projectId: projectId,
                    companyId: profile.companyId,
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: details.isEmpty ? nil : details,
                    dueDate: due,
                    dueTime: time,
                    parentId: parent?.id,
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
