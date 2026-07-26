import SwiftUI

/// Time capture for the person standing on the jobsite.
///
/// The clock is the primary control because that is what actually gets used:
/// the alternative — remembering at 17:00 what time you arrived — is how hours
/// get lost. Manual entry exists for the days somebody forgot.
struct TimeTrackerView: View {
    let projectId: UUID
    let profile: Profile
    var tasks: [JobTask] = []

    @State private var open: TimeEntry?
    @State private var entries: [TimeEntry] = []
    @State private var showManual = false
    @State private var showStop = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var tick = Date()

    /// Redraws the running duration once a second.
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            Section {
                if let open {
                    runningCard(open)
                } else {
                    Button {
                        start()
                    } label: {
                        Label("Start work", systemImage: "play.circle.fill")
                            .font(.headline)
                    }
                    .disabled(isWorking)
                }

                Button {
                    showManual = true
                } label: {
                    Label("Enter hours manually", systemImage: "square.and.pencil")
                        .font(.subheadline)
                }
            } header: {
                Text("Time")
            } footer: {
                if open != nil {
                    Text("The clock keeps running when you close the app.")
                }
            }

            SyncStatusSection()

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
            }

            if !entries.isEmpty {
                Section("Recorded") {
                    ForEach(entries, id: \.id) { entry in
                        TimeEntryRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Hours")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showManual) {
            ManualTimeSheet(projectId: projectId, profile: profile, tasks: tasks) {
                await reload()
            }
        }
        .sheet(isPresented: $showStop) {
            if let open {
                StopWorkSheet(entry: open, elapsedMinutes: elapsedMinutes(open)) { breakMinutes, note in
                    await stop(open, breakMinutes: breakMinutes, note: note)
                }
            }
        }
        .onReceive(clock) { tick = $0 }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func runningCard(_ entry: TimeEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(.green).frame(width: 10, height: 10)
                Text("Running since \(Timestamps.time(entry.startedAt))")
                    .font(.subheadline)
                Spacer()
            }
            Text(elapsedLabel(entry))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Button {
                showStop = true
            } label: {
                Label("Stop", systemImage: "stop.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isWorking)
        }
        .padding(.vertical, 6)
    }

    private func elapsedMinutes(_ entry: TimeEntry) -> Int {
        guard let started = Timestamps.parse(entry.startedAt) else { return 0 }
        return max(0, Int(Date().timeIntervalSince(started)) / 60)
    }

    private func elapsedLabel(_ entry: TimeEntry) -> String {
        guard let started = Timestamps.parse(entry.startedAt) else { return "—" }
        let seconds = max(0, Int(tick.timeIntervalSince(started)))
        return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    private func start() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                open = try await TimeRepo.start(
                    projectId: projectId, profileId: profile.id, taskId: nil)
                errorMessage = nil
            } catch {
                errorMessage = FriendlyError.message(error)
            }
        }
    }

    private func stop(_ entry: TimeEntry, breakMinutes: Int, note: String?) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await TimeRepo.stop(entryId: entry.id, breakMinutes: breakMinutes, note: note)
            open = nil
            await reload()
        } catch {
            errorMessage = FriendlyError.message(error)
        }
    }

    private func reload() async {
        open = try? await TimeRepo.openEntry(profileId: profile.id)
        entries = (try? await TimeRepo.entries(projectId: projectId)) ?? []
    }
}

struct TimeEntryRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.kind == .travel ? "car" : "clock")
                .foregroundStyle(.secondary)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.workDate)
                    .font(.subheadline.weight(.medium))
                Text("\(Timestamps.time(entry.startedAt))–\(Timestamps.time(entry.endedAt)) · \(breakLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = entry.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(Durations.hoursAndMinutes(entry.workedMinutes.map(Int.init)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }

    private var breakLabel: String {
        let minutes = Int(entry.breakMinutes)
        return minutes > 0
            ? String(format: String(localized: "%lld min break"), minutes)
            : String(localized: "no break")
    }
}

enum Durations {
    /// "7 h 15" — how a Rapport reads, rather than "435 minutes".
    static func hoursAndMinutes(_ minutes: Int?) -> String {
        guard let minutes else { return "—" }
        return minutes % 60 == 0
            ? "\(minutes / 60) h"
            : String(format: "%d h %02d", minutes / 60, minutes % 60)
    }
}

/// Entering a shift after the fact.
struct ManualTimeSheet: View {
    let projectId: UUID
    let profile: Profile
    let tasks: [JobTask]
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()
    @State private var start = Calendar.current.date(
        bySettingHour: 7, minute: 30, second: 0, of: Date()) ?? Date()
    @State private var end = Calendar.current.date(
        bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var breakMinutes = 30
    @State private var note = ""
    @State private var kind: TimeEntryKind = .work
    @State private var taskId: UUID?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var workedMinutes: Int {
        let cal = Calendar.current
        let s = cal.dateComponents([.hour, .minute], from: start)
        let e = cal.dateComponents([.hour, .minute], from: end)
        let span = ((e.hour ?? 0) * 60 + (e.minute ?? 0)) - ((s.hour ?? 0) * 60 + (s.minute ?? 0))
        return max(0, span - breakMinutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                    DatePicker("From", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("To", selection: $end, displayedComponents: .hourAndMinute)
                    Stepper(
                        String(format: String(localized: "Break: %lld min"), breakMinutes),
                        value: $breakMinutes, in: 0...240, step: 15
                    )
                } footer: {
                    Text(String(format: String(localized: "Counts as %@"),
                                Durations.hoursAndMinutes(workedMinutes)))
                }

                Section {
                    Picker("Type", selection: $kind) {
                        Text("Work").tag(TimeEntryKind.work)
                        Text("Travel").tag(TimeEntryKind.travel)
                        Text("Standby").tag(TimeEntryKind.standby)
                    }
                    if !tasks.isEmpty {
                        Picker("Work package", selection: $taskId) {
                            Text("—").tag(UUID?.none)
                            ForEach(tasks.filter(\.isWorkPackage), id: \.id) { t in
                                Text(t.title).tag(UUID?.some(t.id))
                            }
                        }
                    }
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Enter hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isWorking || workedMinutes <= 0)
                }
            }
        }
    }

    private func save() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let cal = Calendar.current
                let dayParts = cal.dateComponents([.year, .month, .day], from: day)
                func combine(_ time: Date) -> Date {
                    let t = cal.dateComponents([.hour, .minute], from: time)
                    var c = DateComponents()
                    c.year = dayParts.year; c.month = dayParts.month; c.day = dayParts.day
                    c.hour = t.hour; c.minute = t.minute
                    return cal.date(from: c) ?? time
                }
                // Queued rather than sent. A complete entry is a
                // self-contained operation, so this path behaves identically
                // in a plant room and in the office — the difference is only
                // how long it sits in the outbox.
                let trimmed = note.trimmingCharacters(in: .whitespaces)
                OfflineQueue.shared.enqueue(try PendingOperation(
                    kind: .timeEntry,
                    payload: TimeEntryPayload(
                        projectId: projectId,
                        profileId: profile.id,
                        taskId: taskId,
                        startedAt: combine(start),
                        endedAt: combine(end),
                        breakMinutes: breakMinutes,
                        note: trimmed.isEmpty ? nil : trimmed,
                        kind: kind.rawValue
                    )
                ))
                await onSaved()
                dismiss()
            } catch {
                errorMessage = FriendlyError.message(error)
            }
        }
    }
}

/// Stopping the clock asks for the break, because the law wants it recorded and
/// nobody will go back and add it later.
struct StopWorkSheet: View {
    let entry: TimeEntry
    /// How long the clock has actually run. The break cannot exceed it — the
    /// database enforces that, and offering a value it will reject just turns a
    /// constraint name into the user's problem.
    let elapsedMinutes: Int
    let onStop: (Int, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var breakMinutes = 0
    @State private var note = ""
    @State private var isWorking = false

    private var maxBreak: Int { max(0, elapsedMinutes) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        String(format: String(localized: "Break: %lld min"), breakMinutes),
                        value: $breakMinutes, in: 0...max(maxBreak, 0), step: 15
                    )
                    .disabled(maxBreak == 0)
                    TextField("What did you do?", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("The note appears on the Rapport.")
                }
            }
            .onAppear {
                // A normal shift gets the usual 30 minutes; a short one cannot.
                breakMinutes = min(30, maxBreak)
            }
            .navigationTitle("Stop work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stop") {
                        isWorking = true
                        Task {
                            await onStop(breakMinutes,
                                         note.trimmingCharacters(in: .whitespaces))
                            dismiss()
                        }
                    }
                    .disabled(isWorking)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
