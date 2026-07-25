import SwiftUI

/// Material used on the job. Recorded where it is consumed, so it is still
/// remembered when the Rapport is written.
struct MaterialsView: View {
    let projectId: UUID
    let profile: Profile
    var tasks: [JobTask] = []

    @State private var lines: [MaterialLine] = []
    @State private var showAdd = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading && lines.isEmpty {
                ProgressView()
            } else if lines.isEmpty {
                ContentUnavailableView(
                    "No material recorded",
                    systemImage: "shippingbox",
                    description: Text("Add what was used, so it lands on the Rapport.")
                )
            } else {
                ForEach(lines, id: \.id) { line in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.description).font(.subheadline)
                            Text("\(Quantity.label(line.quantityMilli)) \(line.unit)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if line.unitPriceRappen > 0 {
                            Text(Money.chf(line.quantityMilli * line.unitPriceRappen / 1000))
                                .font(.subheadline).monospacedDigit()
                        }
                    }
                    .swipeActions {
                        if line.recordedBy == profile.id || profile.role.canManageTasks {
                            Button(role: .destructive) {
                                remove(line)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
            }
        }
        .navigationTitle("Material")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddMaterialSheet(projectId: projectId, tasks: tasks) { await reload() }
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func remove(_ line: MaterialLine) {
        Task {
            do {
                try await MaterialRepo.remove(id: line.id)
                await reload()
            } catch {
                errorMessage = FriendlyError.message(error)
            }
        }
    }

    private func reload() async {
        lines = (try? await MaterialRepo.lines(projectId: projectId)) ?? []
        isLoading = false
    }
}

struct AddMaterialSheet: View {
    let projectId: UUID
    let tasks: [JobTask]
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var quantity = "1"
    @State private var unit = "Stk"
    @State private var price = ""
    @State private var taskId: UUID?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private static let units = ["Stk", "m", "m2", "kg", "l", "h", "Pauschal"]

    /// Parses "2.5" or "2,5" into integer thousandths. Comma is what a Swiss
    /// keyboard offers, and no float ever reaches the database.
    private var quantityMilli: Int? {
        let normalised = quantity.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalised), value > 0 else { return nil }
        return Int((value * 1000).rounded())
    }

    private var priceRappen: Int {
        let normalised = price.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalised), value >= 0 else { return 0 }
        return Int((value * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What was used?", text: $description)
                    HStack {
                        TextField("Quantity", text: $quantity)
                            .keyboardType(.decimalPad)
                        Picker("", selection: $unit) {
                            ForEach(Self.units, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                    TextField("Unit price (CHF, optional)", text: $price)
                        .keyboardType(.decimalPad)
                }

                if !tasks.isEmpty {
                    Section {
                        Picker("Work package", selection: $taskId) {
                            Text("—").tag(UUID?.none)
                            ForEach(tasks.filter(\.isWorkPackage), id: \.id) { t in
                                Text(t.title).tag(UUID?.some(t.id))
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Add material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isWorking || quantityMilli == nil
                                  || description.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let milli = quantityMilli else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                _ = try await MaterialRepo.add(
                    projectId: projectId, taskId: taskId,
                    description: description.trimmingCharacters(in: .whitespaces),
                    quantityMilli: milli, unit: unit, unitPriceRappen: priceRappen)
                await onSaved()
                dismiss()
            } catch {
                errorMessage = FriendlyError.message(error)
            }
        }
    }
}
