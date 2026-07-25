import SwiftUI

/// The Rapport list for a project, and the flow that turns recorded time into a
/// signed document.
struct RapportListView: View {
    let projectId: UUID
    let profile: Profile

    @State private var reports: [Report] = []
    @State private var showNew = false
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading && reports.isEmpty {
                ProgressView()
            } else if reports.isEmpty {
                ContentUnavailableView(
                    "No Rapporte yet",
                    systemImage: "doc.text",
                    description: Text("Create one from the hours and materials recorded on this job.")
                )
            } else {
                ForEach(reports, id: \.id) { report in
                    NavigationLink {
                        RapportDetailView(reportId: report.id, profile: profile)
                    } label: {
                        RapportRow(report: report)
                    }
                }
            }
        }
        .navigationTitle("Rapporte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showNew) {
            NewRapportSheet(projectId: projectId, profile: profile) { await reload() }
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        reports = (try? await RapportRepo.reports(projectId: projectId)) ?? []
        isLoading = false
    }
}

struct RapportRow: View {
    let report: Report

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: report.status == .draft ? "doc" : "doc.text.fill")
                .foregroundStyle(report.status == .draft ? Color.secondary : Color.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(report.numberText ?? String(localized: "Draft"))
                    .font(.subheadline.weight(.semibold))
                if let title = report.title, !title.isEmpty {
                    Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if let total = report.totalNetRappen {
                Text(Money.chf(total)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            StatusPill(text: report.status.label, color: report.status.color)
        }
    }
}

enum Money {
    /// Integer Rappen in, "CHF 1'234.55" out. Swiss digit grouping uses an
    /// apostrophe, which Foundation gets right for de_CH.
    static func chf(_ rappen: Int64) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "CHF"
        f.locale = Locale(identifier: "de_CH")
        return f.string(from: NSDecimalNumber(value: Double(rappen) / 100.0))
            ?? String(format: "%.2f", Double(rappen) / 100.0)
    }
}

extension ReportStatus {
    var label: String {
        switch self {
        case .draft: String(localized: "Draft")
        case .signed: String(localized: "Signed")
        case .sent: String(localized: "Sent")
        case .cancelled: String(localized: "Cancelled")
        }
    }

    var color: Color {
        switch self {
        case .draft: .gray
        case .signed: .green
        case .sent: .blue
        case .cancelled: .red
        }
    }
}

struct NewRapportSheet: View {
    let projectId: UUID
    let profile: Profile
    let onCreated: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var summary = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("What was done", text: $summary, axis: .vertical)
                        .lineLimit(3...6)
                } footer: {
                    Text("You will pick the hours and materials in the next step.")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("New Rapport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }.disabled(isWorking)
                }
            }
        }
    }

    private func create() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                _ = try await RapportRepo.createDraft(
                    projectId: projectId,
                    title: title.isEmpty ? nil : title,
                    summary: summary.isEmpty ? nil : summary)
                await onCreated()
                dismiss()
            } catch {
                errorMessage = FriendlyError.message(error)
            }
        }
    }
}

/// A Rapport: pick the hours, add the materials, hand the phone over.
struct RapportDetailView: View {
    let reportId: UUID
    let profile: Profile

    @State private var report: Report?
    @State private var timeLines: [ReportTimeLine] = []
    @State private var materialLines: [ReportMaterialLine] = []
    @State private var available: [TimeEntry] = []
    @State private var selected: Set<UUID> = []
    @State private var showSignature = false
    @State private var shareLink: URL?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var isDraft: Bool { report?.status == .draft }

    var body: some View {
        List {
            if let report {
                Section {
                    HStack {
                        StatusPill(text: report.status.label, color: report.status.color)
                        Spacer()
                        if let number = report.numberText {
                            Text(number).font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                    }
                    if let summary = report.summary, !summary.isEmpty {
                        Text(summary).font(.subheadline)
                    }
                    if let signer = report.signerName {
                        Label(signer, systemImage: "signature")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if isDraft, !available.isEmpty {
                    Section("Add recorded hours") {
                        ForEach(available, id: \.id) { entry in
                            Button {
                                if selected.contains(entry.id) { selected.remove(entry.id) }
                                else { selected.insert(entry.id) }
                            } label: {
                                HStack {
                                    Image(systemName: selected.contains(entry.id)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(Color.accentColor)
                                    TimeEntryRow(entry: entry)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            attach()
                        } label: {
                            Label("Add to Rapport", systemImage: "plus.circle")
                        }
                        .disabled(selected.isEmpty || isWorking)
                    }
                }

                if !timeLines.isEmpty {
                    Section("Hours") {
                        ForEach(timeLines, id: \.id) { line in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.performedOn).font(.subheadline)
                                    if let who = line.performedByName {
                                        Text(who).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(Durations.hoursAndMinutes(Int(line.minutes)))
                                    .font(.subheadline).monospacedDigit()
                            }
                        }
                    }
                }

                if !materialLines.isEmpty {
                    Section("Material") {
                        ForEach(materialLines, id: \.id) { line in
                            HStack {
                                Text(line.description).font(.subheadline)
                                Spacer()
                                Text("\(Quantity.label(line.quantityMilli)) \(line.unit)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if isDraft {
                    Section {
                        Button {
                            showSignature = true
                        } label: {
                            Label("Get customer signature", systemImage: "signature")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isWorking || (timeLines.isEmpty && materialLines.isEmpty))
                    } footer: {
                        if timeLines.isEmpty && materialLines.isEmpty {
                            Text("Add hours or material before signing.")
                        } else {
                            Text("Signing assigns the Rapport number and locks the content.")
                        }
                    }
                } else {
                    Section {
                        Button {
                            makeLink()
                        } label: {
                            Label("Share with customer", systemImage: "square.and.arrow.up")
                        }
                        .disabled(isWorking)
                    } footer: {
                        Text("Creates a link that opens without a login.")
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(report?.title ?? String(localized: "Rapport"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSignature) {
            SignaturePadView(
                reportTitle: report?.title ?? String(localized: "Rapport"),
                onCancel: { showSignature = false },
                onSigned: { png, name in await sign(png: png, name: name) }
            )
        }
        .sheet(item: $shareLink) { url in
            ShareSheet(items: [url])
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func attach() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await RapportRepo.attachTime(reportId: reportId, timeEntryIds: Array(selected))
                selected.removeAll()
                await reload()
            } catch {
                errorMessage = FriendlyError.message(error)
            }
        }
    }

    private func sign(png: Data, name: String) async {
        guard let report else { return }
        isWorking = true
        defer { isWorking = false; showSignature = false }
        do {
            let path = try await RapportRepo.uploadSignature(
                png: png, companyId: profile.companyId, projectId: report.projectId)
            _ = try await RapportRepo.sign(
                reportId: reportId, signerName: name, signaturePath: path)
            await reload()
        } catch {
            errorMessage = FriendlyError.message(error)
        }
    }

    private func makeLink() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let link = try await RapportRepo.createLink(reportId: reportId)
                // The token is only ever returned once, so it goes straight
                // into the share sheet rather than being stored anywhere.
                shareLink = URL(string: "\(Supa.publicSiteURL)/r/\(link.token)")
            } catch {
                errorMessage = FriendlyError.message(error)
            }
        }
    }

    private func reload() async {
        report = try? await RapportRepo.report(id: reportId)
        timeLines = (try? await RapportRepo.timeLines(reportId: reportId)) ?? []
        materialLines = (try? await RapportRepo.materialLines(reportId: reportId)) ?? []
        if let report, report.status == .draft {
            let all = (try? await TimeRepo.entries(projectId: report.projectId)) ?? []
            let used = Set(timeLines.compactMap(\.timeEntryId))
            available = all.filter { $0.endedAt != nil && !used.contains($0.id) }
        } else {
            available = []
        }
    }
}

enum Quantity {
    /// Integer thousandths in, a human quantity out: 2500 -> "2.5", 3000 -> "3".
    static func label(_ milli: Int64) -> String {
        milli % 1000 == 0
            ? String(milli / 1000)
            : String(format: "%.3f", Double(milli) / 1000)
                .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
