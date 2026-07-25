import AVFoundation
import Supabase
import SwiftUI

/// Plays a voice-message attachment (downloads via signed URL, then plays
/// locally so scrubbing/replays are instant).
struct AudioPlayerView: View {
    let attachment: Attachment

    @State private var player = AudioPlayer()

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Task { await player.toggle(bucket: attachment.storageBucket, path: attachment.storagePath) }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 34))
            }
            .disabled(player.isLoading)

            waveform

            Text(durationText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 180)
        // Leaving the thread mid-playback must not leak the repeating timer or
        // leave the playback audio session active.
        .onDisappear { player.stop() }
    }

    private var waveform: some View {
        let bars = waveformBars()
        return HStack(spacing: 2) {
            ForEach(bars.indices, id: \.self) { index in
                Capsule()
                    .fill(Double(index) / Double(bars.count) <= player.progress ? Color.accentColor : Color(.tertiarySystemFill))
                    .frame(width: 3, height: 6 + 20 * CGFloat(bars[index]))
            }
        }
        .frame(height: 30)
    }

    private func waveformBars() -> [Double] {
        // waveform column is jsonb: [0..1] amplitudes, or null.
        if case .array(let values)? = attachment.waveform {
            let doubles = values.compactMap { value -> Double? in
                if case .double(let d) = value { return d }
                if case .integer(let i) = value { return Double(i) }
                return nil
            }
            if !doubles.isEmpty { return doubles }
        }
        return Array(repeating: 0.4, count: 20)
    }

    private var durationText: String {
        let total = Int(attachment.durationSeconds ?? 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

@Observable
@MainActor
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    func toggle(bucket: String, path: String) async {
        if isPlaying {
            player?.pause()
            isPlaying = false
            progressTimer?.invalidate()
            progressTimer = nil
            return
        }

        if player == nil {
            isLoading = true
            defer { isLoading = false }
            do {
                let data = try await Supa.client.storage.from(bucket).download(path: path)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                try AVAudioSession.sharedInstance().setActive(true)
                let player = try AVAudioPlayer(data: data)
                player.delegate = self
                self.player = player
            } catch {
                return
            }
        }

        player?.play()
        isPlaying = true
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.progress = player.duration > 0 ? player.currentTime / player.duration : 0
            }
        }
    }

    /// Stop playback and release the timer + audio session. Called from
    /// onDisappear so navigating away mid-playback doesn't leak either.
    func stop() {
        player?.pause()
        isPlaying = false
        progress = 0
        progressTimer?.invalidate()
        progressTimer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0
            self.progressTimer?.invalidate()
            self.progressTimer = nil
        }
    }
}
