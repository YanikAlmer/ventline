import AVFoundation
import SwiftUI

/// Records an AAC voice message (.m4a, 64 kbps mono) with a live level meter.
struct VoiceRecorderSheet: View {
    let onSend: (URL, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = VoiceRecorder()

    var body: some View {
        VStack(spacing: 16) {
            Text(recorder.isRecording ? "Recording…" : "Voice message")
                .font(.headline)

            // Simple level meter.
            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Float(index) / 24 < recorder.level ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(width: 6, height: 14 + CGFloat(index % 5) * 5)
                }
            }
            .frame(height: 40)

            Text(recorder.durationText)
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.secondary)

            if recorder.permissionDenied {
                Text("Microphone access is off. Enable it in Settings › Ventline to record voice messages.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 24) {
                Button("Cancel", role: .cancel) {
                    recorder.cancel()
                    dismiss()
                }

                if recorder.isRecording {
                    Button {
                        if let result = recorder.stop() {
                            onSend(result.url, result.duration)
                        }
                        dismiss()
                    } label: {
                        Label("Send", systemImage: "arrow.up.circle.fill")
                            .font(.title3.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        recorder.start()
                    } label: {
                        Label("Record", systemImage: "record.circle")
                            .font(.title3.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding()
        .onDisappear { recorder.cancel() }
    }
}

@Observable
@MainActor
final class VoiceRecorder {
    private(set) var isRecording = false
    private(set) var level: Float = 0
    private(set) var duration: TimeInterval = 0
    private(set) var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var fileURL: URL?

    var durationText: String {
        let total = Int(duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    func start() {
        Task { await startRecording() }
    }

    private func startRecording() async {
        // Ask for microphone access before touching the audio session, and
        // surface a clear denied state instead of silently capturing nothing.
        guard await requestMicPermission() else {
            permissionDenied = true
            isRecording = false
            return
        }
        permissionDenied = false

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            // record() returns false if the engine could not start; don't
            // pretend we're recording in that case.
            guard recorder.record() else {
                isRecording = false
                permissionDenied = true
                return
            }

            self.recorder = recorder
            self.fileURL = url
            isRecording = true
            duration = 0

            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tick()
                }
            }
        } catch {
            isRecording = false
        }
    }

    private func requestMicPermission() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func tick() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        // Average power is in dB (-160...0); map to 0...1.
        let db = recorder.averagePower(forChannel: 0)
        level = max(0, min(1, (db + 50) / 50))
        duration = recorder.currentTime
    }

    func stop() -> (url: URL, duration: Double)? {
        guard let recorder, let fileURL else { return nil }
        let finalDuration = recorder.currentTime
        recorder.stop()
        cleanupSession()
        isRecording = false
        // Anything under half a second is an accidental tap.
        guard finalDuration > 0.5 else { return nil }
        return (fileURL, finalDuration)
    }

    func cancel() {
        recorder?.stop()
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        cleanupSession()
        isRecording = false
        level = 0
        duration = 0
    }

    private func cleanupSession() {
        meterTimer?.invalidate()
        meterTimer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
